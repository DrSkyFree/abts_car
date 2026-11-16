import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/display_settings.dart';
import '../core/theme/wide_mode.dart';
import '../widgets/page_scaffold.dart';

/// 屏幕缩放与边距调整（参考车机版常见做法）
///
/// 每一项点一下即时生效：缩放/字号/封面尺寸改的是全局渲染参数，
/// 四周边距按屏幕百分比留白，用来避开被车机状态栏 / 底栏压住的区域。
class DisplayTuningPage extends StatelessWidget {
  const DisplayTuningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = DisplaySettings.instance;
    return PageScaffold(
      title: const Text('屏幕缩放与边距调整'),
      actions: [
        TextButton(
          onPressed: () => ds.resetToPreset(),
          child: Text('恢复默认',
              style: TextStyle(fontSize: 13, color: AppTheme.accent)),
        ),
      ],
      body: AnimatedBuilder(
        animation: ds,
        builder: (context, _) {
          final wide = WideMode.useWideLayout(context);
          final scaleGroup = <Widget>[
            _Stepper(
              label: '缩放',
              value: _pct(ds.scale),
              onMinus: ds.scale > DisplaySettings.minScale
                  ? () => ds.setScale(ds.scale - 0.05)
                  : null,
              onPlus: ds.scale < DisplaySettings.maxScale
                  ? () => ds.setScale(ds.scale + 0.05)
                  : null,
            ),
            _Stepper(
              label: '字号',
              value: _pct(ds.textScale),
              onMinus: ds.textScale > DisplaySettings.minTextScale
                  ? () => ds.setTextScale(ds.textScale - 0.05)
                  : null,
              onPlus: ds.textScale < DisplaySettings.maxTextScale
                  ? () => ds.setTextScale(ds.textScale + 0.05)
                  : null,
            ),
            _Stepper(
              label: '封面尺寸',
              value: _pct(ds.coverScale),
              onMinus: ds.coverScale > DisplaySettings.minCoverScale
                  ? () => ds.setCoverScale(ds.coverScale - 0.05)
                  : null,
              onPlus: ds.coverScale < DisplaySettings.maxCoverScale
                  ? () => ds.setCoverScale(ds.coverScale + 0.05)
                  : null,
            ),
          ];
          final marginGroup = <Widget>[
            _Stepper(
              label: '屏幕上边距',
              value: _pctInt(ds.marginTop),
              onMinus: ds.marginTop > 0
                  ? () => ds.setMarginTop(ds.marginTop - 1)
                  : null,
              onPlus: ds.marginTop < DisplaySettings.maxMargin
                  ? () => ds.setMarginTop(ds.marginTop + 1)
                  : null,
            ),
            _Stepper(
              label: '屏幕下边距',
              value: _pctInt(ds.marginBottom),
              onMinus: ds.marginBottom > 0
                  ? () => ds.setMarginBottom(ds.marginBottom - 1)
                  : null,
              onPlus: ds.marginBottom < DisplaySettings.maxMargin
                  ? () => ds.setMarginBottom(ds.marginBottom + 1)
                  : null,
            ),
            _Stepper(
              label: '屏幕左边距',
              value: _pctInt(ds.marginLeft),
              onMinus: ds.marginLeft > 0
                  ? () => ds.setMarginLeft(ds.marginLeft - 1)
                  : null,
              onPlus: ds.marginLeft < DisplaySettings.maxMargin
                  ? () => ds.setMarginLeft(ds.marginLeft + 1)
                  : null,
            ),
            _Stepper(
              label: '屏幕右边距',
              value: _pctInt(ds.marginRight),
              onMinus: ds.marginRight > 0
                  ? () => ds.setMarginRight(ds.marginRight - 1)
                  : null,
              onPlus: ds.marginRight < DisplaySettings.maxMargin
                  ? () => ds.setMarginRight(ds.marginRight + 1)
                  : null,
            ),
          ];

          final content = wide
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _note(),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: scaleGroup,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: marginGroup,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 32),
                  children: [
                    _note(),
                    const SizedBox(height: 4),
                    ...scaleGroup,
                    const SizedBox(height: 8),
                    ...marginGroup,
                  ],
                );

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: content,
          );
        },
      ),
    );
  }

  static String _pct(double v) => '${(v * 100).round()}%';
  static String _pctInt(double v) => '${v.round()}%';

  Widget _note() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Text(
          '请注意！这里的功能属于特殊适配操作。\n'
          '· 调得太大或太小可能导致页面显示异常，右侧顶部的「恢复默认」可一键还原。\n'
          '· 车机顶部状态栏压住内容时，把「屏幕上边距」调到 6%~10% 即可避开。\n'
          '· 设置即时生效，无需重启应用。',
          style: TextStyle(fontSize: 12, color: AppTheme.textSub, height: 1.6),
        ),
      ),
    );
  }
}

/// 一行「标签 + ─ 数值 ＋」调节器
class _Stepper extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _Stepper({
    required this.label,
    required this.value,
    this.onMinus,
    this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: AppTheme.textMain),
            ),
          ),
          _StepButton(icon: Icons.remove_rounded, onTap: onMinus),
          SizedBox(
            width: 64,
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMain,
                ),
              ),
            ),
          ),
          _StepButton(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      tooltip: icon == Icons.add_rounded ? '增大' : '减小',
    );
  }
}
