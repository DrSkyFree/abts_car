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
import 'core/theme/display_frame.dart';
import 'core/theme/display_settings.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/wide_mode.dart';
import 'pages/home_shell.dart';
import 'pages/splash_screen.dart';
import 'player/bili_audio_handler.dart';
import 'player/book_player.dart';
import 'services/auth_store.dart';
import 'services/cache_notifier.dart';
import 'services/umeng_analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 注意：runApp 之前任何一步抛异常或卡住，系统都会一直停在原生启动图
  // （深空蓝底 + LOGO）上，只能杀进程重进。因此这里逐项 try/catch，
  // 并且不再 await 平台通道调用。
  try {
    // 宽屏/遥控设备优先：强制「传统」焦点高亮模式。
    // 默认自动模式依赖设备上报输入类型，部分安卓车机盒不触发切换，
    // 会导致旋钮/方向键聚焦时按钮自带高亮不显示；聚焦态才绘制，手机端无副作用。
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  } catch (e) {
    debugPrint('[main] focus strategy init failed: $e');
  }
  try {
    // 加载 libmpv；个别车机在低内存时可能失败，失败也不该挡住界面
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('[main] media_kit init failed: $e');
  }

  // 立即渲染启动页（LOGO + 加载动画），初始化在启动页展示期间执行，避免白屏
  runApp(const AbTingShuApp());

  // 方向锁放到首帧之后再发：部分车机的窗口管理平台通道偶发无响应，
  // 在 runApp 之前 await 会让首帧永远出不来，表现为卡在启动图。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values)
        .timeout(const Duration(seconds: 3))
        .catchError((Object e) {
          debugPrint('[main] set orientations failed: $e');
        });
  });
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
      WideMode.detect(),
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
  // 媒体会话放后台：这项工作要绑定前台服务，个别车机上绑定回调可能很慢，
  // 不该让它拖着启动页。BookPlayer 内部对 handler 为空已做兼容。
  unawaited(_initAudioService());
}

/// 绑定系统媒体会话（通知栏 / 方向盘按键 / 锁屏控制）。
///
/// 与启动流程解耦：即使失败或超时，界面照常可用，播放退化为应用内控制。
Future<void> _initAudioService() async {
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
    ).timeout(const Duration(seconds: 8));
    BookPlayer.instance.attachHandler(handler);
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

  /// 启动兜底：初始化万一卡在某个慢平台通道上（车机偶发），
  /// 也不能让用户永远停在启动页，超时后直接进主界面。
  Timer? _splashWatchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _splashWatchdog = Timer(const Duration(seconds: 6), _enterHome);
    _bootstrap().catchError((Object e) {
      // 启动阶段任何异常都不能让界面停在启动页，交给看门狗兜底
      debugPrint('[main] bootstrap failed: $e');
    }).whenComplete(_enterHome);
  }

  /// 进入主界面：初始化完成与看门狗谁先到算谁，重复调用无害。
  void _enterHome() {
    if (!mounted || _ready) return;
    _splashWatchdog?.cancel();
    _splashWatchdog = null;
    setState(() => _ready = true);
    _bootstrapBackground();
  }

  @override
  void dispose() {
    _splashWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 车机会随大灯开关切换系统明暗。AppTheme 的颜色是静态读取的，只有重建才会换色；
  /// 只 setState 首页树，压栈的二级页面（播放页/详情页…）不会重建，会晚一拍甚至不刷新。
  /// 这里在下一帧把整棵 Element 树标记为需要重建：保留 State 与导航栈，只重新 build。
  @override
  void didChangePlatformBrightness() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final root = WidgetsBinding.instance.rootElement;
      if (root == null) return;
      _markNeedsBuildDeep(root);
    });
  }

  /// 深度遍历并重建：跳过已失活的节点，避免个别路由切换瞬间的元素断言
  void _markNeedsBuildDeep(Element element) {
    try {
      element.markNeedsBuild();
    } catch (_) {
      // 已失活/正在卸载的节点忽略即可
    }
    element.visitChildren(_markNeedsBuildDeep);
  }

  /// 退到后台/被系统回收前落库进度，保证下次续播精确到秒
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _repaintOnResume();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      BookPlayer.instance.flushProgress();
    }
  }

  /// 暖启动兜底：车机把应用放后台后再点图标，进程与 FlutterEngine 都还活着，
  /// 新窗口拿不到新帧时 Android 会一直显示启动窗口（深空蓝 + LOGO），
  /// 表现就是「卡在启动图标，退出重进才正常」。回到前台时强制整树重建并绘制一帧。
  void _repaintOnResume() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final root = WidgetsBinding.instance.rootElement;
      if (root == null) return;
      _markNeedsBuildDeep(root);
      WidgetsBinding.instance.scheduleFrame();
    });
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
              return DisplayFrame(child: child);
            },
            home: _ready
                ? KeyedSubtree(
                    key: ValueKey('theme-${tc.mode.name}'),
                    // 不能是 const：系统明暗变化时要能重建，文字颜色才会跟着换
                    child: HomeShell(),
                  )
                : const SplashScreen(),
          );
        },
      ),
    );
  }
}

