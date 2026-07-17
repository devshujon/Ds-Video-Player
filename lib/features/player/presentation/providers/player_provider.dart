import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../media_library/domain/entities/media_item.dart';
import '../../../media_library/domain/usecases/library_usecases.dart';
import '../../data/services/playback_bridge.dart';
import '../../data/services/playback_state_store.dart';
import '../../data/services/video_playback_service.dart';
import '../../domain/entities/playback_args.dart';
import '../../domain/entities/playback_state.dart';
import '../../domain/entities/player_enums.dart';
import '../../domain/services/subtitle_resolver.dart';

export '../../domain/entities/player_enums.dart';

/// media_kit-backed video engine with PiP-ready background session bridge,
/// full resume state, decoder control, and subtitle styling.
class PlayerProvider extends ChangeNotifier implements PlaybackController {
  PlayerProvider({
    required SaveResume saveResume,
    required PlaybackStateStore stateStore,
    DecoderMode decoderMode = DecoderMode.auto,
    this.resumeEnabled = true,
    this.backgroundEnabled = true,
  })  : _saveResume = saveResume,
        _stateStore = stateStore,
        _decoderMode = decoderMode {
    _player = _createPlayer();
    _videoController = VideoController(_player);
    _bindStreams();
  }

  final SaveResume _saveResume;
  final PlaybackStateStore _stateStore;
  final bool resumeEnabled;
  final bool backgroundEnabled;

  DecoderMode _decoderMode;
  DecoderMode get decoderMode => _decoderMode;

  late Player _player;
  late VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subs = [];

  Timer? _persistTicker;
  Timer? _sleepTimer;
  bool _disposed = false;
  int _pendingResumeMs = 0;
  PlaybackState _prefs = const PlaybackState();

  PlaybackArgs? _args;
  int _index = 0;

  @override
  bool isPlaying = false;
  bool isBuffering = true;
  bool isLocked = false;
  bool isRotationLocked = false;
  @override
  Duration position = Duration.zero;
  @override
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
  double subtitleDelaySec = 0;
  double subtitleFontScale = 1.0;
  int subtitleColorArgb = 0xFFFFFFFF;
  double subtitleBackgroundOpacity = 0.5;
  bool subtitleOutline = true;

  String? _currentAudioTrackId;
  List<AudioTrack> _audioTracks = const [];
  List<SubtitleTrack> _subtitleTracks = const [];

  Player get player => _player;
  VideoController get videoController => _videoController;
  List<AudioTrack> get audioTracks => _audioTracks;
  List<SubtitleTrack> get subtitleTracks => _subtitleTracks;
  String? get currentAudioTrackId => _currentAudioTrackId;

  MediaItem? get currentItem =>
      _args == null ? null : _args!.queue[_index];

  @override
  String? get title => currentItem?.title;

  @override
  String? get artist => currentItem?.folderName;

  @override
  String? get artUri => currentItem?.thumbPath;

  @override
  bool get hasNext {
    final args = _args;
    if (args == null) return false;
    return _index + 1 < args.queue.length || repeat == RepeatMode.all;
  }

  @override
  bool get hasPrevious => _index > 0 || position.inSeconds > 3;

  Future<void> start(PlaybackArgs args) async {
    _args = args;
    _index = args.startIndex.clamp(0, args.queue.length - 1);
    _pendingResumeMs = resumeEnabled ? args.resumePositionMs : 0;
    if (backgroundEnabled) PlaybackBridge.attach(this);
    _startPersistTicker();
    await _openCurrent();
  }

  Player _createPlayer() {
    return Player(
      configuration: PlayerConfiguration(
        title: AppConstants.appName,
        bufferSize: 32 * 1024 * 1024,
        ready: () => unawaited(_applyDecoderMode()),
      ),
    );
  }

  Future<void> _setMpvProperty(String name, String value) async {
    try {
      final platform = (_player as dynamic).platform;
      if (platform != null) {
        await (platform as dynamic).setProperty(name, value) as Future<void>;
      }
    } catch (_) {
      // Best-effort — styling/decoding may fall back to defaults.
    }
  }

  Future<void> _applyDecoderMode() async {
    final hwdec = switch (_decoderMode) {
      DecoderMode.auto => 'auto-safe',
      DecoderMode.hardware => 'mediacodec',
      DecoderMode.software => 'no',
    };
    await _setMpvProperty('hwdec', hwdec);
  }

  Future<void> setDecoderMode(DecoderMode mode) async {
    if (_decoderMode == mode) return;
    _decoderMode = mode;
    await _applyDecoderMode();
    notifyListeners();
  }

  void _bindStreams() {
    _subs
      ..add(_player.stream.playing.listen((v) {
        isPlaying = v;
        _syncMediaSession();
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
      }))
      ..add(_player.stream.tracks.listen((tracks) {
        _audioTracks = tracks.audio;
        _subtitleTracks = tracks.subtitle;
        if (_currentAudioTrackId != null) {
          final match =
              tracks.audio.where((t) => t.id == _currentAudioTrackId);
          if (match.isNotEmpty) {
            unawaited(_player.setAudioTrack(match.first));
          }
        }
        notifyListeners();
      }))
      ..add(_player.stream.track.listen((track) {
        _currentAudioTrackId = track.audio.id;
        notifyListeners();
      }));
  }

  Future<void> _openCurrent() async {
    final item = currentItem;
    if (item == null) return;
    errorText = null;
    _completionHandled = false;

    final saved = resumeEnabled ? await _stateStore.load(item.uri) : null;
    if (saved != null) {
      _prefs = saved;
      speed = saved.speed;
      aspectMode = saved.aspectMode;
      videoScale = saved.videoScale;
      subtitleDelaySec = saved.subtitleDelaySec;
      subtitleFontScale = saved.subtitleFontScale;
      subtitleColorArgb = saved.subtitleColorArgb;
      subtitleBackgroundOpacity = saved.subtitleBackgroundOpacity;
      subtitleOutline = saved.subtitleOutline;
      currentSubtitleUri = saved.subtitleUri;
      subtitleEnabled = saved.subtitleEnabled;
      _currentAudioTrackId = saved.audioTrackId;
      if (_pendingResumeMs == 0 && saved.positionMs > 0) {
        _pendingResumeMs = saved.positionMs;
      }
    } else {
      _prefs = const PlaybackState();
    }

    final media = _mediaForUri(item.uri);
    await _player.open(media, play: false);

    if (_pendingResumeMs > 0) {
      await _player.seek(Duration(milliseconds: _pendingResumeMs));
      _pendingResumeMs = 0;
    }
    await _player.setRate(speed);

    if (_currentAudioTrackId != null) {
      final track = _audioTracks.cast<AudioTrack?>().firstWhere(
            (t) => t?.id == _currentAudioTrackId,
            orElse: () => null,
          );
      if (track != null) {
        await _player.setAudioTrack(track);
      }
    }

    await _restoreSubtitle();
    await _applySubtitleStyle();
    await _player.play();
    _syncMediaSession();
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

  void _startPersistTicker() {
    _persistTicker?.cancel();
    _persistTicker =
        Timer.periodic(const Duration(seconds: 8), (_) => _tickPersist());
  }

  void _tickPersist() {
    final item = currentItem;
    if (item == null) return;
    _persistFullState();
    if (position >= AppConstants.resumeMinWatched) {
      _persistResume(item);
    }
  }

  bool _completionHandled = false;

  void _syncMediaSession() => PlaybackBridge.onStateChanged?.call();
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

  @override
  Future<void> mediaPlay() => playPause(alreadyPlaying: false);

  @override
  Future<void> mediaPause() => playPause(alreadyPlaying: true);

  Future<void> playPause({bool? alreadyPlaying}) async {
    final playing = alreadyPlaying ?? isPlaying;
    if (playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  @override
  Future<void> mediaSeek(Duration to) => seek(to);

  Future<void> seek(Duration to) async {
    await _player.seek(to);
    _syncMediaSession();
  }

  Future<void> seekBy(Duration delta) async {
    final target = position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    await seek(clamped);
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
        DeviceOrientation.portraitUp,
      ]);
    }
    notifyListeners();
  }

  @override
  Future<void> mediaSkipNext() => next();

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

  @override
  Future<void> mediaSkipPrevious() => previous();

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

  Future<void> setAudioTrack(AudioTrack track) async {
    _currentAudioTrackId = track.id;
    await _player.setAudioTrack(track);
    notifyListeners();
  }

  Future<void> _restoreSubtitle() async {
    final item = currentItem;
    if (item == null) return;

    if (currentSubtitleUri != null && subtitleEnabled) {
      await loadSubtitle(currentSubtitleUri!, persist: false);
      return;
    }

    final found = await SubtitleResolver.findFor(item.uri);
    if (found != null) {
      await loadSubtitle(found, persist: false);
    }
  }

  Future<void> loadSubtitle(String path, {bool persist = true}) async {
    final uri = path.startsWith('file://') ? path : 'file://$path';
    currentSubtitleUri = path;
    subtitleEnabled = true;
    try {
      await _player.setSubtitleTrack(SubtitleTrack.uri(uri));
      await _applySubtitleStyle();
      if (persist) _persistFullState();
    } catch (e) {
      errorText = 'Could not load subtitle: $e';
    }
    notifyListeners();
  }

  Future<void> loadEmbeddedSubtitle(SubtitleTrack track) async {
    currentSubtitleUri = track.id;
    subtitleEnabled = true;
    await _player.setSubtitleTrack(track);
    await _applySubtitleStyle();
    _persistFullState();
    notifyListeners();
  }

  Future<void> disableSubtitle() async {
    subtitleEnabled = false;
    await _player.setSubtitleTrack(SubtitleTrack.no());
    _persistFullState();
    notifyListeners();
  }

  Future<void> enableSubtitle() async {
    subtitleEnabled = true;
    final uri = currentSubtitleUri;
    if (uri != null) {
      if (uri.startsWith('file') || uri.contains('/')) {
        await loadSubtitle(uri);
      }
    }
    notifyListeners();
  }

  Future<void> setSubtitleDelay(double seconds) async {
    subtitleDelaySec = seconds.clamp(-30.0, 30.0);
    await _applySubtitleStyle();
    _persistFullState();
    notifyListeners();
  }

  Future<void> setSubtitleFontScale(double scale) async {
    subtitleFontScale = scale.clamp(0.5, 2.5);
    await _applySubtitleStyle();
    _persistFullState();
    notifyListeners();
  }

  Future<void> setSubtitleColor(int argb) async {
    subtitleColorArgb = argb;
    await _applySubtitleStyle();
    _persistFullState();
    notifyListeners();
  }

  Future<void> setSubtitleBackgroundOpacity(double opacity) async {
    subtitleBackgroundOpacity = opacity.clamp(0.0, 1.0);
    await _applySubtitleStyle();
    _persistFullState();
    notifyListeners();
  }

  Future<void> setSubtitleOutline(bool enabled) async {
    subtitleOutline = enabled;
    await _applySubtitleStyle();
    _persistFullState();
    notifyListeners();
  }

  Future<void> _applySubtitleStyle() async {
    await _setMpvProperty('sub-delay', subtitleDelaySec.toString());
    await _setMpvProperty('sub-scale', subtitleFontScale.toString());
    final r = (subtitleColorArgb >> 16) & 0xFF;
    final g = (subtitleColorArgb >> 8) & 0xFF;
    final b = subtitleColorArgb & 0xFF;
    final border = subtitleOutline ? 3 : 0;
    final alpha = (subtitleBackgroundOpacity * 255).round();
    await _setMpvProperty(
      'sub-ass-force-style',
      'FontSize=48,PrimaryColour=&H00${b.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}${r.toRadixString(16).padLeft(2, '0')},'
      'Outline=$border,BorderStyle=3,BackColour=&H${alpha.toRadixString(16).padLeft(2, '0')}000000',
    );
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

  void _persistFullState() {
    final item = currentItem;
    if (item == null) return;
    _prefs = PlaybackState(
      positionMs: position.inMilliseconds,
      subtitleUri: currentSubtitleUri,
      subtitleEnabled: subtitleEnabled,
      audioTrackId: _currentAudioTrackId,
      speed: speed,
      aspectMode: aspectMode,
      videoScale: videoScale,
      subtitleDelaySec: subtitleDelaySec,
      subtitleFontScale: subtitleFontScale,
      subtitleColorArgb: subtitleColorArgb,
      subtitleBackgroundOpacity: subtitleBackgroundOpacity,
      subtitleOutline: subtitleOutline,
    );
    unawaited(_stateStore.save(item.uri, _prefs));
    _persistResume(item);
  }

  @override
  Future<void> mediaStop() async {
    await _player.pause();
    _syncMediaSession();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _persistTicker?.cancel();
    _sleepTimer?.cancel();
    final item = currentItem;
    if (item != null) _persistFullState();
    PlaybackBridge.detach(this);
    unawaited(VideoPlaybackService.shutdownIfIdle());
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}
