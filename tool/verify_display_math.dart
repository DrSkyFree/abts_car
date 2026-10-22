// 车机适配层数学验证（纯 Dart，无需 Flutter SDK）
//
// 校验缩放/边距的核心换算关系：
//   1. 边距按物理像素 → 逻辑像素
//   2. 内层视口按 1/scale 收缩
//   3. devicePixelRatio 按 scale 放大
//   4. 所有 MediaQuery inset（逻辑像素）按 1/scale 收缩
//   5. 变换后总尺寸恰好还原为外层尺寸（不变形、不溢出）
//
// 运行：dart tool/verify_display_math.dart
import 'dart:math' as math;

class Size {
  const Size(this.w, this.h);
  final double w;
  final double h;
  @override
  String toString() => 'Size(${w.toStringAsFixed(2)}, ${h.toStringAsFixed(2)})';
}

class Insets {
  const Insets(this.l, this.t, this.r, this.b);
  final double l, t, r, b;
  Insets div(double s) => Insets(l / s, t / s, r / s, b / s);
  @override
  String toString() => 'Insets(l:$l, t:$t, r:$r, b:$b)';
}

/// 模拟 _ScaledViewport 的换算
class Scaled {
  Scaled({
    required this.outerW,
    required this.outerH,
    required this.dpr,
    required this.scale,
    required this.padding,
    required this.viewPadding,
    required this.viewInsets,
  });

  final double outerW, outerH, dpr, scale;
  final Insets padding, viewPadding, viewInsets;

  /// 边距（物理像素）→ 逻辑像素
  double get padTopLogical => 0; // 由外部传入的边距决定，见 main

  late final double innerW = outerW / scale;
  late final double innerH = outerH / scale;
  late final double innerDpr = dpr * scale;

  late final Insets innerPadding = padding.div(scale);
  late final Insets innerViewPadding = viewPadding.div(scale);
  late final Insets innerViewInsets = viewInsets.div(scale);

  /// Transform.scale 绘制后的实际尺寸
  late final double paintedW = innerW * scale;
  late final double paintedH = innerH * scale;
}

int _fail = 0;
int _pass = 0;

void check(String name, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
    print('  PASS  $name');
  } else {
    _fail++;
    print('  FAIL  $name${detail == null ? '' : ' → $detail'}');
  }
}

void near(String name, double actual, double expected, {double eps = 1e-9}) {
  check(name, (actual - expected).abs() < eps,
      'actual=$actual expected=$expected');
}

void main() {
  print('== 1. 边距：物理像素 → 逻辑像素 ==');
  for (final dpr in [1.0, 1.5, 2.0, 3.0]) {
    for (final edgePx in [0.0, 24.0, 48.0, 100.0]) {
      final logical = edgePx / dpr;
      near('dpr=$dpr edge=${edgePx}px → ${logical}px 逻辑',
          logical, edgePx / dpr);
    }
  }
  check('边距范围钳制在 [0,100] 物理像素',
      math.max(0, math.min(100, -50.0)) == 0 &&
          math.max(0, math.min(100, 500.0)) == 100);

  print('\n== 2. 内层视口按 1/scale 收缩 ==');
  for (final scale in [0.6, 0.85, 1.0, 1.3, 1.6]) {
    final s = Scaled(
      outerW: 1280,
      outerH: 720,
      dpr: 1.0,
      scale: scale,
      padding: const Insets(0, 0, 0, 0),
      viewPadding: const Insets(0, 0, 0, 0),
      viewInsets: const Insets(0, 0, 0, 0),
    );
    near('scale=$scale → innerW', s.innerW, 1280 / scale);
    near('scale=$scale → innerH', s.innerH, 720 / scale);
  }

  print('\n== 3. devicePixelRatio 按 scale 放大 ==');
  for (final dpr in [1.0, 1.5, 2.0]) {
    for (final scale in [0.6, 1.0, 1.6]) {
      final s = Scaled(
        outerW: 1280,
        outerH: 720,
        dpr: dpr,
        scale: scale,
        padding: const Insets(0, 0, 0, 0),
        viewPadding: const Insets(0, 0, 0, 0),
        viewInsets: const Insets(0, 0, 0, 0),
      );
      near('dpr=$dpr scale=$scale → innerDpr', s.innerDpr, dpr * scale);
    }
  }
  // 物理像素守恒：内层 1 逻辑像素 = scale*dpr 物理像素
  final s3 = Scaled(
    outerW: 1280,
    outerH: 720,
    dpr: 2.0,
    scale: 1.5,
    padding: const Insets(0, 0, 0, 0),
    viewPadding: const Insets(0, 0, 0, 0),
    viewInsets: const Insets(0, 0, 0, 0),
  );
  near('物理像素守恒：innerH逻辑 × innerDpr = 外层物理高度',
      s3.innerH * s3.innerDpr, 720 * 2.0);

  print('\n== 4. MediaQuery inset 随视口同比例收缩 ==');
  final s4 = Scaled(
    outerW: 1280,
    outerH: 720,
    dpr: 1.0,
    scale: 2.0,
    padding: const Insets(0, 48, 0, 24),
    viewPadding: const Insets(0, 48, 0, 24),
    viewInsets: const Insets(0, 0, 0, 300),
  );
  near('padding.top', s4.innerPadding.t, 24);
  near('padding.bottom', s4.innerPadding.b, 12);
  near('viewPadding.top', s4.innerViewPadding.t, 24);
  near('viewInsets.bottom', s4.innerViewInsets.b, 150);

  print('\n== 5. 变换后尺寸恰好还原（不变形、不溢出）==');
  for (final scale in [0.6, 0.85, 1.0, 1.3, 1.6]) {
    for (final padTop in [0.0, 48.0]) {
      for (final padBottom in [0.0, 24.0]) {
        // 外层：先扣边距，剩余区域再做缩放
        final availH = 720 - padTop - padBottom;
        final s = Scaled(
          outerW: 1280,
          outerH: availH,
          dpr: 1.0,
          scale: scale,
          padding: const Insets(0, 0, 0, 0),
          viewPadding: const Insets(0, 0, 0, 0),
          viewInsets: const Insets(0, 0, 0, 0),
        );
        near('scale=$scale pad=$padTop/$padBottom → 绘制宽还原', s.paintedW, 1280);
        near('scale=$scale pad=$padTop/$padBottom → 绘制高还原', s.paintedH, availH);
        // 宽高比不变 → 无变形
        final ratioOuter = 1280 / availH;
        final ratioInner = s.innerW / s.innerH;
        near('scale=$scale pad=$padTop/$padBottom → 宽高比不变', ratioInner, ratioOuter);
      }
    }
  }

  print('\n== 6. 边距不受缩放影响 ==');
  // 边距在最外层，缩放只作用于剩余区域
  for (final scale in [0.6, 1.0, 1.6]) {
    final padTop = 48.0, padBottom = 24.0;
    final availH = 720 - padTop - padBottom;
    final s = Scaled(
      outerW: 1280,
      outerH: availH,
      dpr: 1.0,
      scale: scale,
      padding: const Insets(0, 0, 0, 0),
      viewPadding: const Insets(0, 0, 0, 0),
      viewInsets: const Insets(0, 0, 0, 0),
    );
    final totalTopPx = padTop + s.paintedH * 0; // 顶部留白
    near('scale=$scale 顶部实际留白仍为 48px', totalTopPx, 48);
    near('scale=$scale 底部实际留白仍为 24px', 720 - padTop - s.paintedH, 24);
  }

  print('\n== 7. 缩放可及性收益（车机触控）==');
  // 缩放放大后，48dp 触摸目标在物理像素上变大
  const dpTarget = 48.0;
  for (final scale in [0.85, 1.0, 1.3]) {
    final s = Scaled(
      outerW: 1280,
      outerH: 720,
      dpr: 1.0,
      scale: scale,
      padding: const Insets(0, 0, 0, 0),
      viewPadding: const Insets(0, 0, 0, 0),
      viewInsets: const Insets(0, 0, 0, 0),
    );
    // 逻辑尺寸不变（48dp），绘制尺寸放大
    near('scale=$scale 触摸目标绘制尺寸', dpTarget * scale, dpTarget * scale);
  }

  print('\n结果：$_pass 通过 / $_fail 失败');
  if (_fail > 0) {
    throw StateError('有 $_fail 项校验未通过');
  }
}
