import 'package:audio_service/audio_service.dart';

import 'book_player.dart';

/// audio_service 桥接：把 BookPlayer 暴露为系统媒体会话，
/// 提供锁屏/通知栏控制、后台播放（Android MediaSession）
class BiliAudioHandler extends BaseAudioHandler {
  BiliAudioHandler() {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.rewind,
          MediaControl.play,
          MediaControl.fastForward,
          MediaControl.skipToNext,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.rewind,
          MediaAction.fastForward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: [0, 1, 2],
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
      ),
    );
  }

  BookPlayer get _player => BookPlayer.instance;

  @override
  Future<void> play() async {
    // 车机语音/方向盘「开始播放」：没有音源时接着上次的位置继续
    await _player.resumeFromMediaCommand();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.next();

  @override
  Future<void> skipToPrevious() => _player.previous();

  @override
  Future<void> fastForward() => _player.seekRelative(15);

  @override
  Future<void> rewind() => _player.seekRelative(-15);

  @override
  Future<void> stop() => _player.stop();
}