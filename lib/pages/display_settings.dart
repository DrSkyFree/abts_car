import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/settings/display_prefs.dart';
import '../../core/theme/app_theme.dart';

/// 车机 / 大屏适配设置面板
///
/// 两种用法：
///  * [embedded]=true → 返回一段可嵌入父级 ListView 的内容（设置页内嵌）；
///  * [embedded]=false → 自带标题栏的独立页面（播放页快捷入口）。
class DisplaySettingsCard extends StatefulWidget {
  const DisplaySettingsCard({super.key, this.embedded = true});

  /// true=可嵌入父级滚动容器的一段内容；false=独立页面（自带 AppBar）
  final bool embedded;

  @override
  State<DisplaySettingsCard> createState() => _DisplaySettingsCardState();
}

class _DisplaySettingsCardState extends State<DisplaySettingsCard> {
  late DisplayPrefs _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = DisplayPrefs.instance;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _prefs,
      builder: (context, _) {
        final content = _buildContent(context);
        if (widget.embedded) return content;
        return Scaffold(
          appBar: AppBar(title: const Text('车机适配')),
          body: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [content],
          ),
        );
      },
    );
  }

  /// 内容主体：Column 而非 ListView，便于嵌入父级滚动容器
  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (DisplayPrefs.isCarBuild)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _tag('当前为车机版（ABTS_CAR）· 已默认锁定横屏'),
          ),
        _statusSummary(),
        _sectionTitle('一键预设'),
        _presetRow(),
        const SizedBox(height: 4),
        _scaleCard(),
        const SizedBox(height: 12),
        _edgeCard(),
        const SizedBox(height: 12),
        _switchCard(),
        const SizedBox(height: 12),
        _tipCard(),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: _prefs.isDefault
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await _prefs.resetDefault();
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('已恢复默认显示设置')),
                    );
                  },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('恢复默认显示设置'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSub,
              disabledForegroundColor: AppTheme.divider,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- 预设 ----------

  /// 当前生效配置摘要
  Widget _statusSummary() {
    final bits = <String>[
      '缩放 ${(_prefs.scale * 100).round()}%',
      if (_prefs.edgeTop > 0) '上留白 ${_prefs.edgeTop.round()}px',
      if (_prefs.edgeBottom > 0) '下留白 ${_prefs.edgeBottom.round()}px',
      if (_prefs.landscapeLock) '横屏',
      if (_prefs.fullscreen) '沉浸式',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(Icons.aspect_ratio_rounded, size: 16, color: AppTheme.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                bits.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in CarPreset.values)
            ActionChip(
              label: Text(p.label, style: const TextStyle(fontSize: 12)),
              backgroundColor: AppTheme.surface,
              side: BorderSide(color: AppTheme.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await _prefs.applyPreset(p);
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('已应用「${p.label}」')),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------- 缩放 ----------

  Widget _scaleCard() {
    final percent = (_prefs.scale * 100).round();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.zoom_in_rounded, size: 18, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                '界面缩放',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '缩小可一屏容纳更多内容；放大可提升车机远距离点按的容错。',
            style: TextStyle(fontSize: 12, color: AppTheme.textSub, height: 1.5),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.accent,
              thumbColor: AppTheme.accent,
              overlayColor: AppTheme.accent.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: _prefs.scale,
              min: DisplayPrefs.minScale,
              max: DisplayPrefs.maxScale,
              divisions: ((DisplayPrefs.maxScale - DisplayPrefs.minScale) * 20)
                  .round(),
              label: '$percent%',
              onChanged: _prefs.setScale,
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final v in const [0.7, 0.85, 1.0, 1.15, 1.3])
                _miniButton(
                  '${(v * 100).round()}%',
                  selected: (_prefs.scale - v).abs() < 0.001,
                  onTap: () => _prefs.setScale(v),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- 边距 ----------

  Widget _edgeCard() {
    final dpr = MediaQuery.of(context).devicePixelRatio <= 0
        ? 1.0
        : MediaQuery.of(context).devicePixelRatio;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.height_rounded, size: 18, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                '显示界面上下边距',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
              const Spacer(),
              Text(
                '本机 ${dpr.toStringAsFixed(2)}x',
                style: TextStyle(fontSize: 11, color: AppTheme.textSub),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '按屏幕物理像素计量，用来避开车机悬浮状态栏 / 底部导航条对按钮的遮挡。',
            style: TextStyle(fontSize: 12, color: AppTheme.textSub, height: 1.5),
          ),
          const SizedBox(height: 6),
          _edgeRow('顶部边距', _prefs.edgeTop, (v) => _prefs.setEdge(top: v)),
          _edgeRow(
            '底部边距',
            _prefs.edgeBottom,
            (v) => _prefs.setEdge(bottom: v),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniButton(
                '状态栏已遮挡？试试 48',
                selected: (_prefs.edgeTop - 48).abs() < 0.001,
                onTap: () => _prefs.setEdge(top: 48),
              ),
              _miniButton(
                '手势条已遮挡？试试 24',
                selected: (_prefs.edgeBottom - 24).abs() < 0.001,
                onTap: () => _prefs.setEdge(bottom: 24),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: (_prefs.edgeTop == 0 && _prefs.edgeBottom == 0)
                      ? null
                      : () => _prefs.setEdge(top: 0, bottom: 0),
                  icon: const Icon(Icons.layers_clear_rounded, size: 18),
                  label: const Text('清零边距'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSub,
                    disabledForegroundColor: AppTheme.divider,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _edgeRow(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.textSub),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.accent,
                thumbColor: AppTheme.accent,
                trackHeight: 3,
              ),
              child: Slider(
                value: value,
                min: DisplayPrefs.minEdge,
                max: DisplayPrefs.maxEdge,
                divisions: 100,
                label: '${value.round()} px',
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 62,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${value.round()} px',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 开关 ----------

  Widget _switchCard() {
    return _card(
      child: Column(
        children: [
          SwitchListTile(
            value: _prefs.landscapeLock,
            onChanged: _prefs.setLandscapeLock,
            activeThumbColor: AppTheme.accent,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '锁定横屏',
              style: TextStyle(fontSize: 14, color: AppTheme.textMain),
            ),
            subtitle: Text(
              '固定横向显示，适合车机固定安装的场景',
              style: TextStyle(fontSize: 12, color: AppTheme.textSub),
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          SwitchListTile(
            value: _prefs.fullscreen,
            onChanged: _prefs.setFullscreen,
            activeThumbColor: AppTheme.accent,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '沉浸式全屏（隐藏状态栏）',
              style: TextStyle(fontSize: 14, color: AppTheme.textMain),
            ),
            subtitle: Text(
              _prefs.fullscreen
                  ? '已隐藏系统状态栏，界面可用空间最大'
                  : '若不打算用边距避让，可直接隐藏系统状态栏',
              style: TextStyle(fontSize: 12, color: AppTheme.textSub),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: AppTheme.textSub),
              const SizedBox(width: 6),
              Text(
                '怎么调最准',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '1. 先开「沉浸式全屏」，能隐藏的状态栏先隐藏掉；\n'
            '2. 仍有遮挡时，用上下边距补足——看截图上按钮被压住的像素高度，往上填；\n'
            '3. 内容显示不全/字太小，把界面缩放往上调；字太大点不准就往下调。\n\n'
            '设置会立即生效并自动保存，下次打开保持不变。',
            style: TextStyle(fontSize: 12, color: AppTheme.textSub, height: 1.7),
          ),
        ],
      ),
    );
  }

  // ---------- 通用小组件 ----------

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMain,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: child,
      ),
    );
  }

  Widget _miniButton(String label, {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accent.withValues(alpha: 0.14)
              : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppTheme.accent : AppTheme.textSub,
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}
