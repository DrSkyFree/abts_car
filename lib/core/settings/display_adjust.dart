import 'package:flutter/material.dart';

import 'display_prefs.dart';

/// 全局车机适配层：上下边距 + 界面缩放
///
/// 挂在 `MaterialApp.builder` 上，整棵树共用一个入口，改动即时全屏生效。
///
/// 实现要点：
///  * **边距在最外层**，用物理像素计量（车机状态栏高度就是物理像素），
///    不受缩放影响——用户填 48 就是真 48px 留白。
///  * **缩放在边距之内**，采用「按 1/scale 缩小布局视口 + Transform 放大还原」
///    而非单纯 `Transform.scale`。前者会同步缩小 `MediaQuery.size`，
///    列表网格列数、间距会真正重排；且命中测试由 RenderTransform 自动逆变换，
///    不会出现「按钮看着在那儿却点不到」的偏移——这对车机（触控精度差、屏幕小）
///    是硬需求。
class DisplayAdjust extends StatelessWidget {
  const DisplayAdjust({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DisplayPrefs.instance,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final prefs = DisplayPrefs.instance;
    final mq = MediaQuery.of(context);
    final dpr = mq.devicePixelRatio <= 0 ? 1.0 : mq.devicePixelRatio;

    // 物理像素 -> 逻辑像素
    final padTop = prefs.edgeTop / dpr;
    final padBottom = prefs.edgeBottom / dpr;

    Widget result = child;
    // 注意：即使 scale == 1 也必须走 _ScaledViewport。
    // 因为边距是在 Padding 层扣掉的，只有它内部会覆写 MediaQuery.size
    // 为「扣边距后的可用区」，跳过会让内层拿到未扣边距的窗口尺寸。
    if (prefs.scale > 0) {
      result = _ScaledViewport(scale: prefs.scale, child: result);
    }

    if (padTop <= 0 && padBottom <= 0) return result;
    return Padding(
      padding: EdgeInsets.only(top: padTop, bottom: padBottom),
      child: result,
    );
  }
}

/// 布局级缩放容器
///
/// 结构：
/// ```
/// SizedBox(外层尺寸 w×h)
/// └── OverflowBox(tight: innerW×innerH)   ← 强制子节点按缩小后的视口布局
///     └── Transform.scale(scale)           ← 绘制时放大回外层尺寸
///         └── MediaQuery(size: innerW×innerH)
///             └── 应用树
/// ```
///
/// `OverflowBox` 保证子节点拿到的是 **innerW×innerH 的紧约束**（而不是被外层
/// 约束裁剪），`Transform.scale` 再把绘制结果按 scale 放大，两者相乘恰好还原
/// 成 w×h，因此既不会变形也不会溢出。
class _ScaledViewport extends StatelessWidget {
  const _ScaledViewport({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return child;

        // 布局视口按 1/scale 收缩，绘制时再放大回原尺寸
        final innerW = w / scale;
        final innerH = h / scale;
        final mq = MediaQuery.of(context);

        // 缩放后的换算关系（对内层而言）：
        //   1 内层逻辑像素 = scale 个外层逻辑像素 = scale*dpr 个物理像素
        // 因此 devicePixelRatio 要「乘」scale——除会让所有按物理像素计算的组件
        // （图片缓存尺寸、通知栏图标尺寸等）算出一半的值。
        final innerDpr = mq.devicePixelRatio * scale;

        // MediaQuery 里的 padding / viewPadding / viewInsets / systemGestureInsets
        // 全部是**逻辑像素**（见 MediaQueryData.fromView：均经
        // EdgeInsets.fromViewPadding(..., devicePixelRatio) 换算），
        // 因此内层视口缩小了 scale 倍，它们也要同比例缩小，
        // 否则 SafeArea 会按未缩放的数值再让一次，造成双重留白。
        EdgeInsets shrink(EdgeInsets e) => EdgeInsets.only(
              left: e.left / scale,
              top: e.top / scale,
              right: e.right / scale,
              bottom: e.bottom / scale,
            );

        return SizedBox(
          width: w,
          height: h,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: innerW,
            maxWidth: innerW,
            minHeight: innerH,
            maxHeight: innerH,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: MediaQuery(
                data: mq.copyWith(
                  size: Size(innerW, innerH),
                  devicePixelRatio: innerDpr,
                  padding: shrink(mq.padding),
                  viewPadding: shrink(mq.viewPadding),
                  viewInsets: shrink(mq.viewInsets),
                  systemGestureInsets: shrink(mq.systemGestureInsets),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
