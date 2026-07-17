import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../media_library/domain/entities/media_item.dart';
import '../../../media_library/domain/usecases/library_usecases.dart';
import '../../domain/entities/playback_args.dart';
import '../../domain/services/subtitle_resolver.dart';

enum RepeatMode { off, one, all }

enum AspectRatioMode { fit, fill, ratio16x9, ratio4x3, original }

/// media_kit-backed video engine — libmpv with hardware decode, broad codec
/// support, and subtitle/audio track switching beyond platform ExoPlayer.
class PlayerProvider extends ChangeNotifier {
  PlayerProvider(
    this._saveResume, {
    this.forceSoftwareDecode = false,
    this.resumeEnabled = true,
  }) {
    _player = Player(
      configuration: PlayerConfiguration(
        vo: forceSoftwareDecode ? 'gpu' : null,
      ),
    );
    _videoController = VideoController(_player);
    _bindStreams();
  }

  final SaveResume _saveResume;
  final bool forceSoftwareDecode;
  final bool resumeEnabled;

  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subs = [];

  Timer? _resumeTicker;
  Timer? _sleepTimer;
  bool _disposed = false;
  int _pendingResumeMs = 0;

  PlaybackArgs? _args;
  int _index = 0;

  bool isPlaying = false;
  bool isBuffering = true;
  bool isLocked = false;
  bool isRotationLocked = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1.0;
  RepeatMode repeat = RepeatMode.off;
  bool shuffle = false;
  String? errorText;
  double videoScale = 1.0;
  AspectRatioMode aspectMode = AspectRatioMode.fit;
  Duration? sleepRemaining;

  String? currentSubtitleUri;
  bool subtitleEnabled = true;

  Player get player => _player;
  VideoController get videoController => _videoController;

  MediaItem? get currentItem =>
      _args == null ? null : _args!.queue[_index];

  Future<void> start(PlaybackArgs args) async {
    _args = args;
    _index = args.startIndex.clamp(0, args.queue.length - 1);
    _pendingResumeMs = resumeEnabled ? args.resumePositionMs : 0;
    _startResumeTicker();
    await _openCurrent();
  }

  void _bindStreams() {
    _subs
      ..add(_player.stream.playing.listen((v) {
        isPlaying = v;
        notifyListeners();
      }))
      ..add(_player.stream.buffering.listen((v) {
        isBuffering = v;
        notifyListeners();
      }))
      ..add(_player.stream.position.listen((v) {
        position = v;
        notifyListeners();
      }))
      ..add(_player.stream.duration.listen((v) {
        duration = v;
        notifyListeners();
      }))
      ..add(_player.stream.completed.listen((done) {
        if (done) _onCompleted();
      }))
      ..add(_player.stream.error.listen((msg) {
        if (msg.isNotEmpty) {
          errorText = 'Playback error: $msg';
          notifyListeners();
        }
      }));
  }

  Future<void> _openCurrent() async {
    final item = currentItem;
    if (item == null) return;
    errorText = null;
    currentSubtitleUri = null;

    final media = _mediaForUri(item.uri);
    await _player.open(media, play: false);

    if (_pendingResumeMs > 0) {
      await _player.seek(Duration(milliseconds: _pendingResumeMs));
      _pendingResumeMs = 0;
    }
    await _player.setRate(speed);
    await _player.play();
    await _autoLoadSubtitle();
    if (!_disposed) notifyListeners();
  }

  Media _mediaForUri(String uri) {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return Media(uri);
    }
    if (uri.startsWith('content://')) {
      return Media(uri);
    }
    if (uri.startsWith('file://')) {
      return Media(uri);
    }
    return Media('file://${File(uri).absolute.path}');
  }

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

  bool _completionHandled = false;
  void _onCompleted() {
    if (_completionHandled) return;
    _completionHandled = true;
    final item = currentItem;
    if (item != null) _persistResume(item, completed: true);
    if (repeat == RepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
      _completionHandled = false;
      return;
    }
    next();
  }

  Future<void> playPause() async {
    await _player.playOrPause();
  }

  Future<void> seek(Duration to) async {
    await _player.seek(to);
  }

  Future<void> seekBy(Duration delta) async {
    final target = position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    await _player.seek(clamped);
  }

  Future<void> setSpeed(double value) async {
    speed = value.clamp(
      AppConstants.minPlaybackSpeed,
      AppConstants.maxPlaybackSpeed,
    );
    await _player.setRate(speed);
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = RepeatMode.values[(repeat.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void toggleLock() {
    isLocked = !isLocked;
    notifyListeners();
  }

  void setVideoScale(double scale) {
    videoScale = scale.clamp(0.5, 3.0);
    notifyListeners();
  }

  void cycleAspectMode() {
    aspectMode = AspectRatioMode
        .values[(aspectMode.index + 1) % AspectRatioMode.values.length];
    notifyListeners();
  }

  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    sleepRemaining = after;
    if (after == null) {
      notifyListeners();
      return;
    }
    final end = DateTime.now().add(after);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = end.difference(DateTime.now());
      if (left <= Duration.zero) {
        t.cancel();
        sleepRemaining = null;
        _player.pause();
        notifyListeners();
        return;
      }
      sleepRemaining = left;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> toggleRotationLock() async {
    isRotationLocked = !isRotationLocked;
    if (isRotationLocked) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    notifyListeners();
  }

  Future<void> next() async {
    final args = _args;
    if (args == null) return;
    if (_index + 1 < args.queue.length) {
      _index++;
    } else if (repeat == RepeatMode.all) {
      _index = 0;
    } else {
      return;
    }
    _completionHandled = false;
    await _openCurrent();
  }

  Future<void> previous() async {
    if (position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_index > 0) {
      _index--;
      _completionHandled = false;
      await _openCurrent();
    }
  }

  Future<void> _autoLoadSubtitle() async {
    final item = currentItem;
    if (item == null) return;
    final found = await SubtitleResolver.findFor(item.uri);
    if (found != null) {
      await loadSubtitle(found);
    }
  }

  Future<void> loadSubtitle(String path) async {
    currentSubtitleUri = path;
    subtitleEnabled = true;
    try {
      await _player.setSubtitleTrack(
        SubtitleTrack.uri(path.startsWith('file://') ? path : 'file://$path'),
      );
    } catch (e) {
      errorText = 'Could not load subtitle: $e';
    }
    notifyListeners();
  }

  Future<void> disableSubtitle() async {
    subtitleEnabled = false;
    await _player.setSubtitleTrack(SubtitleTrack.no());
    notifyListeners();
  }

  Future<void> enableSubtitle() async {
    subtitleEnabled = true;
    final uri = currentSubtitleUri;
    if (uri != null) await loadSubtitle(uri);
    notifyListeners();
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

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _resumeTicker?.cancel();
    _sleepTimer?.cancel();
    final item = currentItem;
    if (item != null) _persistResume(item);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}
