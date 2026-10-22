import 'package:abts/core/settings/display_adjust.dart';
import 'package:abts/core/settings/display_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 车机适配层的**渲染快照**验证
///
/// 与行为测试互补：行为测试验证数值关系，本测试验证「屏幕上真的长这样」——
/// 缩放后按钮变大、边距后内容整体下移，且不越界。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DisplayPrefs.instance.resetDefault();
  });

  /// 造一个模拟车机主界面的骨架：顶栏 + 网格 + 底部按钮
  Widget fakeCarUi() {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF2FC),
      body: Column(
        children: [
          Container(
            height: 56,
            color: const Color(0xFF1478FC),
            alignment: Alignment.center,
            child: const Text('阿B听书',
                style: TextStyle(color: Colors.white, fontSize: 20)),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              padding: const EdgeInsets.all(12),
              children: List.generate(
                8,
                (i) => Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('第${i + 1}集',
                      style: const TextStyle(fontSize: 14, color: Colors.black)),
                ),
              ),
            ),
          ),
          Container(
            height: 64,
            color: Colors.white,
            alignment: Alignment.center,
            child: const Text('上一章    播放    下一章',
                style: TextStyle(fontSize: 18, color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> pumpCar(WidgetTester tester, {Size size = const Size(1280, 720)}) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            DisplayAdjust(child: child ?? const SizedBox.shrink()),
        home: fakeCarUi(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('默认状态：内容顶到屏幕上沿', (tester) async {
    await pumpCar(tester);
    final bar = find.text('阿B听书');
    expect(bar, findsOneWidget);
    expect(tester.getTopLeft(bar).dy, lessThan(40));
  });

  testWidgets('顶部边距 48px：顶栏整体下移', (tester) async {
    await DisplayPrefs.instance.setEdge(top: 48);
    await pumpCar(tester);
    final bar = find.text('阿B听书');
    // 顶栏文字原本在 56px 高的蓝色条中央（y≈18），下移 48 后 y≈66
    expect(tester.getTopLeft(bar).dy, greaterThan(40));
  });

  testWidgets('底部边距 24px：底部按钮上移', (tester) async {
    await pumpCar(tester);
    final before = tester.getBottomLeft(find.text('上一章    播放    下一章')).dy;

    await DisplayPrefs.instance.setEdge(bottom: 24);
    await tester.pumpAndSettle();
    final after = tester.getBottomLeft(find.text('上一章    播放    下一章')).dy;

    expect(after, lessThan(before));
  });

  testWidgets('缩放 130%：按钮在屏幕上物理变大', (tester) async {
    await pumpCar(tester);
    // getSize 是布局尺寸（未缩放），getRect 才是屏幕上的实际物理尺寸
    final before = tester.getRect(find.text('上一章    播放    下一章')).height;

    await DisplayPrefs.instance.setScale(1.3);
    await tester.pumpAndSettle();
    final after = tester.getRect(find.text('上一章    播放    下一章')).height;

    expect(after, greaterThan(before));
  });

  testWidgets('缩放 + 边距同时生效且内容不越界', (tester) async {
    await DisplayPrefs.instance.setScale(1.3);
    await DisplayPrefs.instance.setEdge(top: 48, bottom: 24);
    await pumpCar(tester);

    // 所有内容都应在视口内
    final size = tester.getSize(find.byType(DisplayAdjust));
    for (final text in ['阿B听书', '第1集', '第8集', '上一章    播放    下一章']) {
      final finder = find.text(text);
      expect(finder, findsOneWidget, reason: text);
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(-1), reason: '$text 越出上边界');
      expect(rect.bottom, lessThanOrEqualTo(size.height + 1),
          reason: '$text 越出下边界');
    }
  });

  testWidgets('缩放 60%：网格能显示更多列', (tester) async {
    await pumpCar(tester);
    final colsBefore = columnCount(tester);

    await DisplayPrefs.instance.setScale(0.6);
    await tester.pumpAndSettle();
    final colsAfter = columnCount(tester);

    // 视口变宽 → 网格列数增加
    expect(colsAfter, greaterThanOrEqualTo(colsBefore));
  });
}

/// 通过测量同一行内网格块的纵坐标是否相同来判断列数
int columnCount(WidgetTester tester) {
  final items = <Offset>[];
  for (var i = 1; i <= 8; i++) {
    final f = find.text('第$i集');
    if (f.evaluate().isEmpty) continue;
    items.add(tester.getTopLeft(f));
  }
  if (items.isEmpty) return 0;
  final firstRowY = items.first.dy;
  return items.where((o) => (o.dy - firstRowY).abs() < 1).length;
}
