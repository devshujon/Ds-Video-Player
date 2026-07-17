import 'dart:async';

import 'package:audio_service/audio_service.dart' as bg;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../media_library/domain/entities/media_item.dart';
import '../../../media_library/domain/usecases/library_usecases.dart';

/// App-scoped audio engine. Independent of the video engine
/// (`PlayerProvider` / video_player). Backed by just_audio 0.9.x.
class AudioEngineProvider extends ChangeNotifier {
  AudioEngineProvider(this._saveResume) {
    _bindStreams();
    _startResumeTicker();
  }

  final SaveResume _saveResume;
  final AudioPlayer _player = AudioPlayer();

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _resumeTicker;

  List<MediaItem> _queue = const [];
  int _currentIndex = 0;

  bool isPlaying = false;
  bool isBuffering = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1.0;
  LoopMode loopMode = LoopMode.off;
  bool shuffle = false;
  String? errorText;

  AudioPlayer get player => _player;

  List<MediaItem> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get hasQueue => _queue.isNotEmpty;

  MediaItem? get currentItem {
    if (_queue.isEmpty) return null;
    final i = _currentIndex.clamp(0, _queue.length - 1);
    return _queue[i];
  }

  /// Replaces the current queue with [items] and starts playback.
  /// Idempotent: calling again with a new queue switches cleanly.
  Future<void> startQueue(
    List<MediaItem> items, {
    int startIndex = 0,
    int resumeMs = 0,
    bool autoPlay = true,
  }) async {
    if (items.isEmpty) return;
    _queue = List.unmodifiable(items);
    _currentIndex = startIndex.clamp(0, items.length - 1);
    errorText = null;
    notifyListeners();

    final sources = <AudioSource>[
      for (final m in items)
        AudioSource.uri(
          _resolveUri(m.uri),
          tag: bg.MediaItem(
            id: m.uri,
            title: m.title,
            album: m.folderName,
            duration: m.durationMs > 0
                ? Duration(milliseconds: m.durationMs)
                : null,
          ),
        ),
    ];

    try {
      // just_audio 0.9.x — single AudioSource wrapped in
      // ConcatenatingAudioSource for a queue. (`setAudioSources` is the
      // 0.10+ API; the resolved pub version stayed on 0.9.46.)
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: _currentIndex,
        initialPosition: Duration(milliseconds: resumeMs),
      );
      if (autoPlay) await _player.play();
    } catch (e) {
      errorText = 'Audio engine error: $e';
      notifyListeners();
    }
  }

  /// `content://` and `http(s)` URIs flow through; bare paths become
  /// `file://` URIs that just_audio's native side resolves correctly.
  Uri _resolveUri(String raw) {
    if (raw.startsWith('content://') ||
        raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('file://')) {
      return Uri.parse(raw);
    }
    return Uri.file(raw);
  }

  void _bindStreams() {
    _subs
      ..add(_player.playingStream.listen((v) {
        isPlaying = v;
        notifyListeners();
      }))
      ..add(_player.processingStateStream.listen((s) {
        isBuffering =
            s == ProcessingState.buffering || s == ProcessingState.loading;
        if (s == ProcessingState.completed) _onCompleted();
        notifyListeners();
      }))
      ..add(_player.positionStream.listen((v) {
        position = v;
        notifyListeners();
      }))
      ..add(_player.durationStream.listen((v) {
        duration = v ?? Duration.zero;
        notifyListeners();
      }))
      ..add(_player.currentIndexStream.listen((i) {
        if (i != null && i != _currentIndex) {
          _currentIndex = i;
          notifyListeners();
        }
      }))
      ..add(_player.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace _) {
          errorText = 'Playback error: $e';
          notifyListeners();
        },
      ));
  }

  /// Saves resume position every 5s so a crash/kill loses at most 5 seconds.
  void _startResumeTicker() {
    _resumeTicker?.cancel();
    _resumeTicker =
        Timer.periodic(const Duration(seconds: 5), (_) => _tickResume());
  }

  void _tickResume() {
    final item = currentItem;
    if (item == null) return;
    if (position < AppConstants.resumeMinWatched) return;
    _persistResume(item);
  }

  void _onCompleted() {
    final item = currentItem;
    if (item != null) _persistResume(item, completed: true);
  }

  void _persistResume(MediaItem item, {bool completed = false}) {
    final pos = completed ? 0 : position.inMilliseconds;
    if (duration.inMilliseconds <= 0) return;
    unawaited(_saveResume(
      uri: item.uri,
      positionMs: pos,
      durationMs: duration.inMilliseconds,
    ));
  }

  // --- Transport ---

  Future<void> playPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration to) => _player.seek(to);

  Future<void> seekBy(Duration delta) async {
    final target = position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    await _player.seek(clamped);
  }

  Future<void> next() => _player.seekToNext();

  Future<void> previous() async {
    if (position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> setSpeed(double v) async {
    speed = v.clamp(
      AppConstants.minPlaybackSpeed,
      AppConstants.maxPlaybackSpeed,
    );
    await _player.setSpeed(speed);
    notifyListeners();
  }

  Future<void> cycleLoop() async {
    loopMode =
        LoopMode.values[(loopMode.index + 1) % LoopMode.values.length];
    await _player.setLoopMode(loopMode);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    shuffle = !shuffle;
    await _player.setShuffleModeEnabled(shuffle);
    if (shuffle) await _player.shuffle();
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _queue = const [];
    _currentIndex = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    final item = currentItem;
    if (item != null) _persistResume(item);
    _resumeTicker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
