import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import 'playback_bridge.dart';
import 'video_audio_handler.dart';

/// Lazily starts the foreground playback service exactly once.
class VideoPlaybackService {
  VideoPlaybackService._();

  static AudioHandler? _handler;
  static bool _initializing = false;
  static bool _audioSessionConfigured = false;
  static bool _wasPlayingBeforeInterruption = false;
  static final List<StreamSubscription<dynamic>> _sessionSubs = [];

  static Future<void> _configureAudioSession() async {
    if (_audioSessionConfigured) return;
    _audioSessionConfigured = true;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.movie,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    _sessionSubs
      ..add(session.becomingNoisyEventStream.listen((_) {
        unawaited(PlaybackBridge.active?.mediaPause());
      }))
      ..add(session.interruptionEventStream.listen((event) {
        if (event.begin) {
          _wasPlayingBeforeInterruption =
              PlaybackBridge.active?.isPlaying ?? false;
          if (event.type != AudioInterruptionType.duck) {
            unawaited(PlaybackBridge.active?.mediaPause());
          }
        } else if (_wasPlayingBeforeInterruption) {
          _wasPlayingBeforeInterruption = false;
          unawaited(PlaybackBridge.active?.mediaPlay());
        }
      }));
  }

  static Future<AudioHandler?> ensureStarted() async {
    if (_handler != null) return _handler;
    if (_initializing) return _handler;
    _initializing = true;
    try {
      await _configureAudioSession();
      _handler = await AudioService.init(
        builder: VideoAudioHandler.new,
        config: AudioServiceConfig(
          androidNotificationChannelId:
              'com.devshujon.ds_video_player.playback',
          androidNotificationChannelName: 'Video playback',
          androidNotificationChannelDescription:
              'Controls for DS Video Player',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: false,
          androidShowNotificationBadge: false,
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
        ),
      );
      return _handler;
    } finally {
      _initializing = false;
    }
  }

  static Future<void> stop() async {
    final h = _handler;
    if (h != null) {
      await h.stop();
    }
  }
}
