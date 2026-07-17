import 'package:audio_service/audio_service.dart';

import 'playback_bridge.dart';

/// Foreground MediaSession + notification controls for video playback.
class VideoAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  VideoAudioHandler() {
    PlaybackBridge.onStateChanged = _syncFromBridge;
    _syncFromBridge();
  }

  void _syncFromBridge() {
    final c = PlaybackBridge.active;
    if (c == null) {
      mediaItem.add(null);
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        controls: const [],
      ));
      return;
    }

    mediaItem.add(
      MediaItem(
        id: c.title ?? 'video',
        title: c.title ?? 'Video',
        artist: c.artist ?? 'DS Video Player',
        artUri: c.artUri != null ? Uri.tryParse(c.artUri!) : null,
        duration: c.duration > Duration.zero ? c.duration : null,
      ),
    );

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (c.hasPrevious) MediaControl.skipToPrevious,
          c.isPlaying ? MediaControl.pause : MediaControl.play,
          if (c.hasNext) MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: [
          if (c.hasPrevious) 0,
          if (c.hasPrevious) 1 else 0,
          if (c.hasPrevious) 2 else 1,
        ],
        processingState: AudioProcessingState.ready,
        playing: c.isPlaying,
        updatePosition: c.position,
        bufferedPosition: c.duration,
        speed: 1.0,
      ),
    );
  }

  @override
  Future<void> play() async {
    await PlaybackBridge.active?.mediaPlay();
    _syncFromBridge();
  }

  @override
  Future<void> pause() async {
    await PlaybackBridge.active?.mediaPause();
    _syncFromBridge();
  }

  @override
  Future<void> seek(Duration position) async {
    await PlaybackBridge.active?.mediaSeek(position);
    _syncFromBridge();
  }

  @override
  Future<void> skipToNext() async {
    await PlaybackBridge.active?.mediaSkipNext();
    _syncFromBridge();
  }

  @override
  Future<void> skipToPrevious() async {
    await PlaybackBridge.active?.mediaSkipPrevious();
    _syncFromBridge();
  }

  @override
  Future<void> stop() async {
    await PlaybackBridge.active?.mediaStop();
    await super.stop();
    _syncFromBridge();
  }
}
