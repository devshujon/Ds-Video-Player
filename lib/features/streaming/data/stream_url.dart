/// Pure helpers for network stream URLs. Validation is intentionally
/// permissive on scheme — video_player (ExoPlayer on Android) resolves
/// HTTP(S)/HLS/DASH. RTSP/RTMP stay in the supported set for future
/// pluggable backends; ExoPlayer ignores them at playback time.
class StreamUrl {
  StreamUrl._();

  static const Set<String> supportedSchemes = {
    'http',
    'https',
    'rtsp',
    'rtmp',
    'rtmps',
  };

  /// True when [input] parses to an absolute URL with a supported scheme
  /// and a non-empty host.
  static bool isValid(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null) return false;
    return uri.hasScheme &&
        supportedSchemes.contains(uri.scheme.toLowerCase()) &&
        uri.host.isNotEmpty;
  }

  /// A human-friendly title: the last non-empty path segment, else host.
  static String titleFor(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return url;
    final segments =
        uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);
    if (segments.isNotEmpty) return segments.last;
    return uri.host.isNotEmpty ? uri.host : url;
  }
}
