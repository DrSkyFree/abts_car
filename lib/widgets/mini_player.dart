import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../pages/player_page.dart';
import '../player/book_player.dart';
import '../widgets/book_cover.dart';

/// 底部迷你播放条
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _syncSpin(bool playing) {
    if (playing) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      if (_spin.isAnimating) _spin.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<BookPlayer>();
    if (!player.loaded || player.book == null) {
      _spin.stop();
      return const SizedBox.shrink();
    }

    final chapter = player.currentChapter;
    final playing = player.isPlaying;
    _syncSpin(playing);

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
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            children: [
              // 主驾在左：播放/暂停放最左侧，伸手就能按到
              _buildButton(player),
              const SizedBox(width: 12),
              _buildDisc(player, playing),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.book!.cleanTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMain,
                      ),
                    ),
                    if (chapter != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '第 ${chapter.page} 章 · ${chapter.part}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textMain.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 26,
                color: AppTheme.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 左侧旋转唱片：播放时持续旋转，暂停时停在当前角度并叠加播放图标
  Widget _buildDisc(BookPlayer player, bool playing) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RotationTransition(
            turns: _spin,
            child: ClipOval(
              child: BookCover(
                url: player.book!.pic,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          if (!playing)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  /// 播放/暂停：强调色实心圆按钮，位于最左侧，车机上易辨认、易点中
  Widget _buildButton(BookPlayer player) {
    final loading = player.loading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : player.togglePlay,
        child: Container(
          width: 60,
          height: 60,
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
                  size: 34,
                ),
        ),
      ),
    );
  }
}