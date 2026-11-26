import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../pages/player_page.dart';
import '../player/book_player.dart';
import 'marquee_text.dart';

/// 底部迷你播放条
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<BookPlayer>();
    if (!player.loaded || player.book == null) {
      return const SizedBox.shrink();
    }

    final chapter = player.currentChapter;
    final titleStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppTheme.textMain,
    );
    final subStyle = TextStyle(
      fontSize: 12.5,
      color: AppTheme.textMain.withValues(alpha: 0.7),
    );

    return Material(
      color: AppTheme.surface,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlayerPage()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.divider)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
          child: Row(
            children: [
              // 主驾在左：播放/暂停放最左侧，伸手就能按到
              _MiniPlayButton(player: player),
              // 按钮与文字之间留出足够呼吸感
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MarqueeText(player.book!.cleanTitle, style: titleStyle),
                    if (chapter != null) ...[
                      const SizedBox(height: 3),
                      MarqueeText(
                        '第 ${chapter.page} 章 · ${chapter.part}',
                        style: subStyle,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 30,
                color: AppTheme.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 播放/暂停：强调色实心圆按钮，车机上易辨认、易点中
class _MiniPlayButton extends StatelessWidget {
  final BookPlayer player;
  const _MiniPlayButton({required this.player});

  @override
  Widget build(BuildContext context) {
    final loading = player.loading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : player.togglePlay,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accent,
                Color.lerp(AppTheme.accent, Colors.black, 0.26)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.40),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(19),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
        ),
      ),
    );
  }
}