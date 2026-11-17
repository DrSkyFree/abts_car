import 'package:abts/widgets/marquee_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 车机播放条的标题滚动：放得下时静止，超出宽度时向左循环滚动
void main() {
  testWidgets('放得下时静止显示，不滚动', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: MarqueeText('第 1 章 · 片花', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final finder = find.text('第 1 章 · 片花');
    expect(finder, findsOneWidget);
    final x1 = tester.getTopLeft(finder).dx;
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(finder).dx, x1);
  });

  testWidgets('超出宽度时自动向左滚动', (tester) async {
    const text = '这是一个非常长的章节标题，用来验证车机播放条上的自动滚动效果';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              child: MarqueeText(text, style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final first = find.text(text).first;
    final x1 = tester.getTopLeft(first).dx;
    await tester.pump(const Duration(seconds: 2));
    final x2 = tester.getTopLeft(first).dx;
    expect(x2, lessThan(x1));
  });
}
