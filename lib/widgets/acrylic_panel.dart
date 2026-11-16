import 'dart:ui';

import 'package:flutter/material.dart';

/// 亚克力（毛玻璃）面板：半透明渐变底 + 背景模糊 + 细描边 + 柔和投影。
///
/// 车机中控多为深色壁纸，纯色卡片会和背景糊在一起；毛玻璃加高光描边
/// 能把内容层次拉开，同时保持文字对比度。
class AcrylicPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? tint;

  const AcrylicPanel({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding,
    this.margin,
    this.blur = 18,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ?? (dark ? const Color(0xFF141820) : Colors.white);
    final r = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.34 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(alpha: dark ? 0.58 : 0.76),
                  base.withValues(alpha: dark ? 0.36 : 0.52),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.16 : 0.6),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
