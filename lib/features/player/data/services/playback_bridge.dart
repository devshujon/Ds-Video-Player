/// Contract between [PlayerProvider] and the background [VideoAudioHandler].
abstract class PlaybackController {
  String? get title;
  String? get artist;
  String? get artUri;
  bool get isPlaying;
  Duration get position;
  Duration get duration;
  bool get hasNext;
  bool get hasPrevious;

  Future<void> mediaPlay();
  Future<void> mediaPause();
  Future<void> mediaSeek(Duration position);
  Future<void> mediaSkipNext();
  Future<void> mediaSkipPrevious();
  Future<void> mediaStop();
}

/// Global holder for the active video session — used by audio_service.
class PlaybackBridge {
  PlaybackBridge._();

  static PlaybackController? active;
  static void Function()? onStateChanged;

  static void attach(PlaybackController controller) {
    active = controller;
    onStateChanged?.call();
  }

  static void detach(PlaybackController controller) {
    if (active == controller) {
      active = null;
      onStateChanged?.call();
    }
  }
}
