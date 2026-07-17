/// Central registry of every supported extension. Used by the scanner to
/// classify files and by the UI to advertise compatibility.
class MediaFormats {
  MediaFormats._();

  static const Set<String> videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'wmv', 'webm', 'ts', 'mts', 'm2ts',
    'mpg', 'mpeg', 'vob', 'asf', 'rm', 'rmvb', '3gp', 'm4v', 'ogv',
  };

  static const Set<String> audioExtensions = {
    'mp3', 'aac', 'wav', 'flac', 'ogg', 'opus', 'm4a', 'wma', 'ac3', 'dts',
    'amr', 'aiff', 'mid', 'midi', 'ape',
  };

  static const Set<String> imageExtensions = {
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tif', 'tiff', 'heic', 'svg',
  };

  static const Set<String> subtitleExtensions = {
    'srt', 'ass', 'ssa', 'vtt',
  };

  static MediaType? classify(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = path.substring(dot + 1).toLowerCase();
    if (videoExtensions.contains(ext)) return MediaType.video;
    if (audioExtensions.contains(ext)) return MediaType.audio;
    if (imageExtensions.contains(ext)) return MediaType.image;
    return null;
  }

  static bool isSubtitle(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    return subtitleExtensions.contains(path.substring(dot + 1).toLowerCase());
  }
}

enum MediaType { video, audio, image }
