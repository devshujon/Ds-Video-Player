import 'dart:io';

import '../../../../core/constants/media_formats.dart';

/// Looks for a sidecar subtitle file (`movie.srt`, `.ass`, `.ssa`, `.vtt`)
/// next to a media file, matched by basename.
class SubtitleResolver {
  SubtitleResolver._();

  static Future<String?> findFor(String mediaPath) async {
    try {
      final dot = mediaPath.lastIndexOf('.');
      if (dot < 0) return null;
      final base = mediaPath.substring(0, dot);
      for (final ext in MediaFormats.subtitleExtensions) {
        final candidate = '$base.$ext';
        if (await File(candidate).exists()) return candidate;
        final candidateUpper = '$base.${ext.toUpperCase()}';
        if (await File(candidateUpper).exists()) return candidateUpper;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
