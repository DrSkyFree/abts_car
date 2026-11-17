import 'package:flutter/material.dart';

/// 单行文字：放得下就静态显示，放不下就从右向左无缝循环滚动（跑马灯）。
///
/// 车机播放条空间有限，章节名往往很长，用滚动代替省略号，保证信息完整可读。
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  /// 两段文字之间的间隔（滚动时可见的空白）
  final double gap;

  /// 滚动速度，逻辑像素/秒
  final double velocity;

  const MarqueeText(
    this.text, {
    super.key,
    required this.style,
    this.gap = 56,
    this.velocity = 34,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  int _durationMs = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, cons) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        final textWidth = painter.width;
        final height = painter.height;
        painter.dispose();

        // 放得下（或宽度不受限）→ 静态显示，不滚动
        if (!cons.hasBoundedWidth || textWidth <= cons.maxWidth) {
          if (_controller.isAnimating) {
            // build 期间不直接停控制器，推到帧后，避免监听者被重复标记重建
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _controller.stop();
            });
          }
          return SizedBox(
            height: height,
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: widget.style,
            ),
          );
        }

        final travel = textWidth + widget.gap;
        final ms = (travel / widget.velocity * 1000)
            .round()
            .clamp(2400, 24000)
            .toInt();
        if (ms != _durationMs) {
          _durationMs = ms;
          _controller.duration = Duration(milliseconds: ms);
        }
        if (!_controller.isAnimating) {
          // 放到帧后启动，避免 build 期间触发监听者重建
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_controller.isAnimating) _controller.repeat();
          });
        }

        return SizedBox(
          height: height,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(-_controller.value * travel, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.text,
                          maxLines: 1,
                          softWrap: false,
                          style: widget.style,
                        ),
                        SizedBox(width: widget.gap),
                        Text(
                          widget.text,
                          maxLines: 1,
                          softWrap: false,
                          style: widget.style,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
