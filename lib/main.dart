import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'core/network/bili_client.dart';
import 'core/storage/bookmark_store.dart';
import 'core/storage/cache_store.dart';
import 'core/storage/follow_store.dart';
import 'core/storage/search_history_store.dart';
import 'core/storage/shelf_store.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/display_settings.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/tv_mode.dart';
import 'pages/home_shell.dart';
import 'pages/splash_screen.dart';
import 'player/bili_audio_handler.dart';
import 'player/book_player.dart';
import 'services/auth_store.dart';
import 'services/cache_notifier.dart';
import 'services/umeng_analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 电视端优先：强制「传统」焦点高亮模式。
  // 默认自动模式依赖设备上报输入类型，部分安卓 TV/盒子不触发切换，
  // 会导致遥控器聚焦时按钮自带高亮不显示；聚焦态才绘制，手机端无副作用。
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  MediaKit.ensureInitialized();
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  // 立即渲染启动页（LOGO + 加载动画），初始化在启动页展示期间执行，避免白屏
  runApp(const AbTingShuApp());
}

/// 第一阶段：启动关键初始化。
///
/// 全部为本地操作（SharedPreferences / 播放器 / 媒体服务），不做任何网络
/// 请求；整体 6 秒超时兜底，任何一项异常都不会把用户卡在启动页。
Future<void> _bootstrap() async {
  try {
    await Future.wait([
      BiliClient.instance.initLocal(),
      ShelfStore.instance.load(),
      ThemeController.instance.load(),
      SearchHistoryStore.instance.load(),
      LoginStore.instance.load(),
      FollowStore.instance.load(),
      BookmarkStore.instance.load(),
      CacheStore.instance.load(),
      DisplaySettings.instance.load(),
      TvMode.detect(),
    ]).timeout(const Duration(seconds: 6));
  } catch (e) {
    debugPrint('[main] local init failed: $e');
  }

  // 播放器初始化 + 系统媒体会话绑定（失败也进主界面，播放时自动降级）
  final player = BookPlayer.instance;
  player.setup();
  // 离线缓存：后台队列 + 通知栏进度
  final cache = CacheStore.instance;
  CacheNotifier.wire(cache);
  // 进程被杀/用户划掉重进后，自动接着下上次没下完的缓存
  cache.enableResume(
    resolver: (bvid, cid) => player.resolveUrlFor(bvid, cid),
    headers: player.downloadHeaders,
  );
  try {
    final handler = await AudioService.init(
      builder: () => BiliAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'dev.pages.abts.channel.audio',
        androidNotificationChannelName: '阿B听书',
        androidNotificationChannelDescription: '播放有声小说',
        androidNotificationIcon: 'mipmap/ic_launcher',
        // 暂停（含来电打断）时保留前台服务与通知，避免打断后通知栏直接消失。
        // 注意：audio_service 要求此时 androidNotificationOngoing 必须为 false。
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidNotificationClickStartsActivity: true,
      ),
    ).timeout(const Duration(seconds: 6));
    player.attachHandler(handler);
  } catch (e) {
    debugPrint('[main] audio service init failed: $e');
  }
}

/// 第二阶段：非关键请求（统计 / 网络预热 / 登录态刷新）。
///
/// 全部在进入主界面之后后台执行，即使全部失败或长时间无响应，
/// 也只影响对应功能的可用性，绝不阻塞用户进入页面。
/// （通知权限改为首次播放时按需申请，见 BookPlayer）
void _bootstrapBackground() {
  unawaited(AppAnalytics.init());
  unawaited(BiliClient.instance.warmupIfNeeded());
  if (BiliClient.instance.isLoggedIn) {
    unawaited(LoginStore.instance.refreshFromNav());
  }
}

class AbTingShuApp extends StatefulWidget {
  const AbTingShuApp({super.key});

  @override
  State<AbTingShuApp> createState() => _AbTingShuAppState();
}

class _AbTingShuAppState extends State<AbTingShuApp>
    with WidgetsBindingObserver {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap().whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      _bootstrapBackground();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 退到后台/被系统回收前落库进度，保证下次续播精确到秒
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      BookPlayer.instance.flushProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ShelfStore.instance),
        ChangeNotifierProvider.value(value: BookPlayer.instance),
        ChangeNotifierProvider.value(value: LoginStore.instance),
        ChangeNotifierProvider.value(value: SearchHistoryStore.instance),
        ChangeNotifierProvider.value(value: FollowStore.instance),
        ChangeNotifierProvider.value(value: BookmarkStore.instance),
        ChangeNotifierProvider.value(value: CacheStore.instance),
      ],
      child: AnimatedBuilder(
        animation: Listenable.merge([tc, DisplaySettings.instance]),
        builder: (context, _) {
          AppTheme.mode = tc.mode;
          return MaterialApp(
            title: '阿B听书',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: tc.mode,
            // 全局面板：字号补偿 + 宽屏方向键导航 + 车机的缩放/边距。
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();
              return _DisplayFrame(child: child);
            },
            home: _ready
                ? KeyedSubtree(
                    key: ValueKey('theme-${tc.mode.name}'),
                    child: const HomeShell(),
                  )
                : const SplashScreen(),
          );
        },
      ),
    );
  }
}

/// 全局面板：把「字号缩放 / 界面缩放 / 四周边距」套到整棵组件树。
///
/// 车机中控的状态栏是系统覆盖层，应用拿到的 `MediaQuery.padding` 往往为 0，
/// 内容会被顶栏压住；这里用占屏幕百分比的边距留出安全区。界面缩放采用
/// 「缩小逻辑视口 + 等比放大绘制」的方式（与系统显示大小调节一致），
/// 所以字体、按钮、列表、封面一起等比变化，且文字仍是矢量绘制不会糊。
class _DisplayFrame extends StatelessWidget {
  final Widget child;
  const _DisplayFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final ds = DisplaySettings.instance;
    final wide = TvMode.useWideLayout(context);
    // 电视端字号补偿（车机走自己的字号设置，避免与 TV 补偿叠加）
    final tvScaler = TvMode.textScalerFor(context);
    final textScaler = TextScaler.linear(
      (tvScaler?.scale(1.0) ?? mq.textScaler.scale(1.0)) * ds.textScale,
    );

    // 没有 AppBar 的宽屏页面也要保证状态栏图标与主题明暗一致
    final overlay = Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

    final insets = ds.insetsFor(mq.size);
    final hasInsets = insets.top > 0 ||
        insets.bottom > 0 ||
        insets.left > 0 ||
        insets.right > 0;
    final zoom = ds.scale;

    // 系统上报的内边距是外层物理尺寸，换算到缩放后的逻辑坐标系；
    // 车机拿不到状态栏留白（padding 为 0），由用户设置的边距补足。
    EdgeInsets scaled(EdgeInsets e) => EdgeInsets.fromLTRB(
          e.left / zoom,
          e.top / zoom,
          e.right / zoom,
          e.bottom / zoom,
        );

    MediaQueryData base() => mq.copyWith(
          textScaler: textScaler,
          navigationMode:
              wide ? NavigationMode.directional : mq.navigationMode,
        );

    Widget content;
    if (hasInsets || zoom != 1.0) {
      final availW =
          (mq.size.width - insets.horizontal).clamp(1.0, mq.size.width);
      final availH =
          (mq.size.height - insets.vertical).clamp(1.0, mq.size.height);
      final logical = Size(availW / zoom, availH / zoom);
      content = Padding(
        padding: insets,
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: logical.width,
              height: logical.height,
              child: MediaQuery(
                data: base().copyWith(
                  size: logical,
                  padding: scaled(mq.padding),
                  viewPadding: scaled(mq.viewPadding),
                  viewInsets: scaled(mq.viewInsets),
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    } else {
      content = MediaQuery(data: base(), child: child);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: content,
    );
  }
}