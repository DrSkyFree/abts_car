import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/display_settings.dart';
import '../core/theme/theme_controller.dart';
import '../widgets/page_scaffold.dart';
import 'display_tuning_page.dart';

/// 外观模式（独立页面）：配色模式 + 屏幕缩放与边距
class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  String _label(ThemeMode m) => switch (m) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };

  String _desc(ThemeMode m) => switch (m) {
    ThemeMode.system => '自动匹配系统深色/浅色外观',
    ThemeMode.light => '明亮配色，适合白天',
    ThemeMode.dark => '深色护眼，适合夜间收听',
  };

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;
    final ds = DisplaySettings.instance;
    return PageScaffold(
      title: const Text('外观模式'),
      body: AnimatedBuilder(
        animation: Listenable.merge([tc, ds]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 32),
            children: [
              _sectionTitle('外观模式'),
              RadioGroup<ThemeMode>(
                groupValue: tc.mode,
                onChanged: (v) {
                  if (v != null) tc.setMode(v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in const [
                      ThemeMode.system,
                      ThemeMode.light,
                      ThemeMode.dark,
                    ])
                      RadioListTile<ThemeMode>(
                        value: m,
                        activeColor: AppTheme.accent,
                        secondary: Icon(switch (m) {
                          ThemeMode.system => Icons.brightness_auto_rounded,
                          ThemeMode.light => Icons.light_mode_rounded,
                          ThemeMode.dark => Icons.dark_mode_rounded,
                        }, color: AppTheme.textSub),
                        title: Text(
                          _label(m),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMain,
                          ),
                        ),
                        subtitle: Text(
                          _desc(m),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionTitle('屏幕'),
              ListTile(
                leading: Icon(
                  Icons.aspect_ratio_rounded,
                  color: AppTheme.accent,
                ),
                title: Text(
                  '屏幕缩放与边距调整',
                  style: TextStyle(fontSize: 14, color: AppTheme.textMain),
                ),
                subtitle: Text(
                  _summary(ds),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSub),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textHint,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DisplayTuningPage()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _summary(DisplaySettings ds) {
    final parts = <String>[
      '缩放 ${(ds.scale * 100).round()}%',
      '字号 ${(ds.textScale * 100).round()}%',
      '封面 ${(ds.coverScale * 100).round()}%',
    ];
    if (ds.marginTop > 0) parts.add('上边距 ${ds.marginTop.round()}%');
    if (ds.marginBottom > 0) parts.add('下边距 ${ds.marginBottom.round()}%');
    if (ds.marginLeft > 0) parts.add('左边距 ${ds.marginLeft.round()}%');
    if (ds.marginRight > 0) parts.add('右边距 ${ds.marginRight.round()}%');
    return parts.join(' · ');
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
}
