import 'package:abts/core/theme/display_frame.dart';
import 'package:abts/core/theme/display_settings.dart';
import 'package:abts/widgets/book_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 车机适配的自动化验收：不接车机，直接校验 1920x720 中控屏上
/// 「状态栏避让 / 字号 / 封面 / 即时生效」四项的实际计算结果。
void main() {
  final ds = DisplaySettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ds.setDevice(DeviceProfile.phone);
    await ds.resetToPreset();
  });

  group('车机预设', () {
    test('切换车机后套用预设：字号 1.3、封面 0.85、顶边距 7%', () async {
      await ds.setDevice(DeviceProfile.car);
      expect(ds.isCar, isTrue);
      expect(ds.scale, 1.0);
      expect(ds.textScale, 1.3);
      expect(ds.coverScale, 0.85);
      expect(ds.marginTop, 7);
      expect(ds.marginBottom, 0);
      expect(ds.marginLeft, 0);
      expect(ds.marginRight, 0);
    });

    test('1920x720 上顶边距换算为 50.4 逻辑像素', () async {
      await ds.setDevice(DeviceProfile.car);
      final insets = ds.insetsFor(const Size(1920, 720));
      expect(insets.top, closeTo(50.4, 0.001));
      expect(insets.horizontal, 0);
    });

    test('预设会持久化到 SharedPreferences', () async {
      await ds.setDevice(DeviceProfile.car);
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('display_device'), 'car');
      expect(sp.getDouble('display_text_scale'), 1.3);
      expect(sp.getDouble('display_margin_top'), 7);
    });

    test('切回手机清空所有调整', () async {
      await ds.setDevice(DeviceProfile.car);
      await ds.setDevice(DeviceProfile.phone);
      expect(ds.isCar, isFalse);
      expect(ds.textScale, 1.0);
      expect(ds.coverScale, 1.0);
      expect(ds.insetsFor(const Size(1920, 720)), EdgeInsets.zero);
    });
  });

  group('取值范围', () {
    test('各项调节都被限制在允许区间内', () async {
      await ds.setScale(9);
      await ds.setTextScale(9);
      await ds.setCoverScale(0.1);
      await ds.setMarginTop(-5);
      expect(ds.scale, DisplaySettings.maxScale);
      expect(ds.textScale, DisplaySettings.maxTextScale);
      expect(ds.coverScale, DisplaySettings.minCoverScale);
      expect(ds.marginTop, 0);
    });

    test('每次调节都会通知监听者（即时生效的基础）', () async {
      var notified = 0;
      void listener() => notified++;
      ds.addListener(listener);
      await ds.setTextScale(1.5);
      await ds.setMarginTop(9);
      ds.removeListener(listener);
      expect(notified, 2);
    });
  });

  group('1920x720 车机屏渲染', () {
    Future<MediaQueryData> pumpCarScreen(WidgetTester tester) async {
      // 车机中控典型分辨率；dpr=1 时逻辑尺寸与物理一致，便于断言
      tester.view.physicalSize = const Size(1920, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await ds.setDevice(DeviceProfile.car);

      late MediaQueryData captured;
      await tester.pumpWidget(
        AnimatedBuilder(
          animation: ds,
          builder: (_, _) => MaterialApp(
            // 与 main.dart 一致：整棵树套在 DisplayFrame 里
            builder: (context, child) => DisplayFrame(child: child!),
            home: Builder(
              builder: (context) {
                captured = MediaQuery.of(context);
                return const Scaffold(body: SizedBox.expand());
              },
            ),
          ),
        ),
      );
      return captured;
    }

    MediaQueryData current(WidgetTester tester) =>
        MediaQuery.of(tester.element(find.byType(Scaffold)));

    testWidgets('状态栏避让：内容视口顶部让出 7%，高度变为 669.6', (tester) async {
      final mq = await pumpCarScreen(tester);
      expect(mq.size.width, 1920);
      expect(mq.size.height, closeTo(669.6, 0.01));

      // 绘制区整体下移 50.4，避开中控状态栏
      final rect = tester.getRect(find.byType(FittedBox).first);
      expect(rect.top, closeTo(50.4, 0.01));
      expect(rect.height, closeTo(669.6, 0.01));
    });

    testWidgets('字号：文字缩放系数为 1.3，且使用方向键导航', (tester) async {
      final mq = await pumpCarScreen(tester);
      expect(mq.textScaler.scale(16), closeTo(20.8, 0.001));
      expect(mq.navigationMode, NavigationMode.directional);
    });

    testWidgets('即时生效：改动字号与边距后无需重启立即重建', (tester) async {
      await pumpCarScreen(tester);

      await ds.setTextScale(1.6);
      await ds.setMarginTop(12);
      await tester.pump();

      final mq = current(tester);
      expect(mq.textScaler.scale(16), closeTo(25.6, 0.001));
      expect(mq.size.height, closeTo(720 * 0.88, 0.01));
    });

    testWidgets('整体缩放 1.2：逻辑视口缩小到 1600x558，再等比放大绘制', (tester) async {
      await pumpCarScreen(tester);
      await ds.setScale(1.2);
      await tester.pump();

      final mq = current(tester);
      expect(mq.size.width, closeTo(1600, 0.01));
      expect(mq.size.height, closeTo(669.6 / 1.2, 0.01));
    });
  });

  group('封面列数', () {
    Future<int> colsAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late int cols;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              cols = bookGridColumns(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return cols;
    }

    testWidgets('1920 宽：手机预设 8 列，车机预设因封面 0.85 变为 9 列', (tester) async {
      await ds.setDevice(DeviceProfile.phone);
      expect(await colsAt(tester, const Size(1920, 720)), 8);
      await ds.setDevice(DeviceProfile.car);
      expect(await colsAt(tester, const Size(1920, 720)), 9);
    });

    testWidgets('封面尺寸独立可调：调到 1.3 后同一块屏只剩 7 列', (tester) async {
      await ds.setDevice(DeviceProfile.car);
      expect(await colsAt(tester, const Size(1920, 720)), 9);
      await ds.setCoverScale(1.3);
      expect(await colsAt(tester, const Size(1920, 720)), 7);
    });

    testWidgets('手机竖屏 390 宽保持 3 列', (tester) async {
      await ds.setDevice(DeviceProfile.phone);
      expect(await colsAt(tester, const Size(390, 844)), 3);
    });
  });
}
