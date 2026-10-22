import 'package:abts/core/settings/display_adjust.dart';
import 'package:abts/core/settings/display_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 车机适配层行为测试
///
/// 覆盖：边距换算（物理像素→逻辑像素）、缩放对视口的收缩、
/// MediaQuery 各项 inset 的同步折算、配置持久化与边界钳制、
/// 以及缩放后触摸命中是否仍与视觉位置一致（车机最关键的诉求）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 按生产环境的真实用法搭建：DisplayAdjust 挂在 MaterialApp.builder 上
  /// （位于 Navigator 之上），拿到的是窗口的紧约束。
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1280, 720),
    double dpr = 1.0,
    EdgeInsets viewPadding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
    Widget? home,
  }) async {
    tester.view
      ..devicePixelRatio = dpr
      ..physicalSize = size * dpr
      // view.padding / view.viewPadding / view.viewInsets 单位是物理像素
      ..padding = FakeViewPadding(
        top: viewPadding.top * dpr,
        bottom: viewPadding.bottom * dpr,
        left: viewPadding.left * dpr,
        right: viewPadding.right * dpr,
      )
      ..viewPadding = FakeViewPadding(
        top: viewPadding.top * dpr,
        bottom: viewPadding.bottom * dpr,
        left: viewPadding.left * dpr,
        right: viewPadding.right * dpr,
      )
      ..viewInsets = FakeViewPadding(
        top: viewInsets.top * dpr,
        bottom: viewInsets.bottom * dpr,
        left: viewInsets.left * dpr,
        right: viewInsets.right * dpr,
      );
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            DisplayAdjust(child: child ?? const SizedBox.shrink()),
        home: home ?? const SizedBox.shrink(),
      ),
    );
  }

  group('配置读写', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // DisplayPrefs 是单例，必须显式重置内存态，否则测试间互相污染
      await DisplayPrefs.instance.resetDefault();
    });

    test('默认值为未适配状态', () {
      final p = DisplayPrefs.instance;
      expect(p.scale, DisplayPrefs.defaultScale);
      expect(p.edgeTop, 0);
      expect(p.edgeBottom, 0);
      expect(p.isDefault, isTrue);
    });

    test('缩放被钳制在 [0.6, 1.6]', () async {
      final p = DisplayPrefs.instance;
      await p.setScale(0.1);
      expect(p.scale, DisplayPrefs.minScale);
      await p.setScale(9.0);
      expect(p.scale, DisplayPrefs.maxScale);
      await p.setScale(double.nan);
      expect(p.scale, DisplayPrefs.defaultScale);
    });

    test('边距被钳制在 [0, 100]', () async {
      final p = DisplayPrefs.instance;
      await p.setEdge(top: -50, bottom: 500);
      expect(p.edgeTop, DisplayPrefs.minEdge);
      expect(p.edgeBottom, DisplayPrefs.maxEdge);
    });

    test('边距可独立调节，且写入本地', () async {
      final p = DisplayPrefs.instance;
      await p.setEdge(top: 48);
      expect(p.edgeBottom, 0);
      await p.setEdge(bottom: 24);
      expect(p.edgeTop, 48);
      expect(p.edgeBottom, 24);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getDouble('car_edge_top'), 48);
      expect(sp.getDouble('car_edge_bottom'), 24);
    });

    test('恢复默认会清空已保存的值', () async {
      final p = DisplayPrefs.instance;
      await p.setScale(1.3);
      await p.setEdge(top: 40, bottom: 40);
      expect(p.isDefault, isFalse);

      await p.resetDefault();
      expect(p.scale, DisplayPrefs.defaultScale);
      expect(p.edgeTop, 0);
      expect(p.edgeBottom, 0);
      expect(p.isDefault, isTrue);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getDouble('car_ui_scale'), isNull);
      expect(sp.getDouble('car_edge_top'), isNull);
    });

    test('预设「避开状态栏」填入上下留白', () async {
      await DisplayPrefs.instance.applyPreset(CarPreset.statusBarAvoid);
      expect(DisplayPrefs.instance.edgeTop, 48);
      expect(DisplayPrefs.instance.edgeBottom, 24);
    });
  });

  group('适配层渲染', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DisplayPrefs.instance.resetDefault();
    });

    testWidgets('默认无缩放无边距时，视口与物理尺寸一致', (tester) async {
      late Size innerSize;
      await pumpApp(tester, home: Builder(builder: (context) {
        innerSize = MediaQuery.of(context).size;
        return const SizedBox.shrink();
      }));
      expect(innerSize, const Size(1280, 720));
    });

    testWidgets('边距按物理像素换算为逻辑像素', (tester) async {
      late Size innerSize;
      // dpr = 2：填 48 物理像素 = 24 逻辑像素，32 物理像素 = 16 逻辑像素
      await DisplayPrefs.instance.setEdge(top: 48, bottom: 32);
      await pumpApp(
        tester,
        dpr: 2.0,
        home: Builder(builder: (context) {
          innerSize = MediaQuery.of(context).size;
          return const SizedBox.shrink();
        }),
      );
      expect(innerSize.width, 1280);
      expect(innerSize.height, 720 - 24 - 16);
    });

    testWidgets('scale=1 时 MediaQuery 仍反映扣边距后的可用区', (tester) async {
      // 回归用例：曾因「scale==1 时跳过缩放容器」导致内层拿到未扣边距的尺寸，
      // 页面内容会被状态栏遮住。
      late Size innerSize;
      await DisplayPrefs.instance.setEdge(top: 60, bottom: 30);
      await pumpApp(tester, home: Builder(builder: (context) {
        innerSize = MediaQuery.of(context).size;
        return const SizedBox.shrink();
      }));
      expect(innerSize.height, 720 - 90);
    });

    testWidgets('缩放收缩内层布局视口', (tester) async {
      late Size innerSize;
      await DisplayPrefs.instance.setScale(0.6);
      await pumpApp(tester, home: Builder(builder: (context) {
        innerSize = MediaQuery.of(context).size;
        return const SizedBox.shrink();
      }));
      // 布局视口应为外层的 1/scale
      expect(innerSize.width, closeTo(1280 / 0.6, 1e-9));
      expect(innerSize.height, closeTo(720 / 0.6, 1e-9));
      // 适配层自身尺寸仍等于窗口（未被撑大）
      expect(tester.getSize(find.byType(DisplayAdjust)), const Size(1280, 720));
    });

    testWidgets('内层 devicePixelRatio 按 scale 放大折算', (tester) async {
      late double innerDpr;
      await DisplayPrefs.instance.setScale(1.5);
      await pumpApp(tester, dpr: 2.0, home: Builder(builder: (context) {
        innerDpr = MediaQuery.of(context).devicePixelRatio;
        return const SizedBox.shrink();
      }));
      // 1 内层逻辑像素 = 1.5 外层逻辑像素 = 3.0 物理像素
      expect(innerDpr, closeTo(3.0, 1e-9));
    });

    testWidgets('上下边距不受缩放影响（外层）', (tester) async {
      // 边距在最外层，缩放只作用于剩余区域：
      // 内容在**外层坐标**里的起始位置恒为 48px，与 scale 无关。
      for (final scale in [0.6, 1.0, 1.6]) {
        await DisplayPrefs.instance.setEdge(top: 48, bottom: 48);
        await DisplayPrefs.instance.setScale(scale);
        await pumpApp(tester, home: const SizedBox.expand(key: ValueKey('probe')));
        await tester.pumpAndSettle();

        final topLeft = tester.getTopLeft(find.byKey(const ValueKey('probe')));
        // 外层坐标下的顶部留白 = 48 物理像素（dpr=1）
        expect(topLeft.dy, closeTo(48, 0.5), reason: 'scale=$scale');
      }
    });

    testWidgets('修改配置会立即重建并生效', (tester) async {
      late Size innerSize;
      await pumpApp(tester, home: Builder(builder: (context) {
        innerSize = MediaQuery.of(context).size;
        return const SizedBox.shrink();
      }));
      expect(innerSize.height, 720);

      await DisplayPrefs.instance.setEdge(top: 60);
      await tester.pumpAndSettle();
      expect(innerSize.height, 660);
    });

    testWidgets('边距与缩放叠加时同时生效', (tester) async {
      late Size innerSize;
      await DisplayPrefs.instance.setEdge(top: 40, bottom: 40);
      await DisplayPrefs.instance.setScale(0.8);
      await pumpApp(tester, home: Builder(builder: (context) {
        innerSize = MediaQuery.of(context).size;
        return const SizedBox.shrink();
      }));

      // 内层视口 = (可用区) / scale
      expect(innerSize.height, closeTo((720 - 80) / 0.8, 1e-9));
      expect(innerSize.width, closeTo(1280 / 0.8, 1e-9));
    });

    testWidgets('viewPadding 随缩放折算，SafeArea 不双重留白', (tester) async {
      late EdgeInsets innerPadding;
      // scale 上限是 1.6，用 1.6 验证：48 / 1.6 = 30
      await DisplayPrefs.instance.setScale(DisplayPrefs.maxScale);
      await pumpApp(
        tester,
        viewPadding: const EdgeInsets.only(top: 48, bottom: 24),
        home: Builder(builder: (context) {
          innerPadding = MediaQuery.of(context).viewPadding;
          return const SizedBox.shrink();
        }),
      );
      expect(innerPadding.top, closeTo(48 / DisplayPrefs.maxScale, 1e-9));
      expect(innerPadding.bottom, closeTo(24 / DisplayPrefs.maxScale, 1e-9));
    });

    testWidgets('键盘 inset 随缩放折算', (tester) async {
      late EdgeInsets innerInsets;
      await DisplayPrefs.instance.setScale(1.5);
      await pumpApp(
        tester,
        viewInsets: const EdgeInsets.only(bottom: 300),
        home: Builder(builder: (context) {
          innerInsets = MediaQuery.of(context).viewInsets;
          return const SizedBox.shrink();
        }),
      );
      // 300 / 1.5 = 200
      expect(innerInsets.bottom, closeTo(200, 1e-9));
    });

    testWidgets('缩放后按钮的触摸命中与视觉位置一致', (tester) async {
      // 车机核心诉求：放大后按钮变大，且仍然点得到
      var tapped = 0;
      await DisplayPrefs.instance.setScale(1.5);
      await pumpApp(
        tester,
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => tapped++,
              child: const Text('播放'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.text('播放');
      expect(button, findsOneWidget);
      // 视觉位置上的中心点点击应命中按钮
      await tester.tap(button);
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('缩放后右下角按钮仍可点击（不越界）', (tester) async {
      // 验证 OverflowBox + Transform 的组合没有把内容推出可视区
      var tapped = 0;
      await DisplayPrefs.instance.setScale(1.5);
      await pumpApp(
        tester,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: () => tapped++,
              child: const Text('右下'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('右下'));
      await tester.pump();
      expect(tapped, 1);
    });
  });
}
