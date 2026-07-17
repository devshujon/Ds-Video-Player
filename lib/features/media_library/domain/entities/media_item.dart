import 'package:equatable/equatable.dart';

import '../../../../core/constants/media_formats.dart';

/// A single playable/viewable item. Pure domain model — no Flutter imports.
class MediaItem extends Equatable {
  const MediaItem({
    required this.uri,
    required this.title,
    required this.type,
    required this.folderPath,
    required this.sizeBytes,
    required this.durationMs,
    required this.dateAddedMs,
    required this.dateModifiedMs,
    this.width,
    this.height,
    this.mimeType,
    this.thumbPath,
    this.isHidden = false,
    this.isFavorite = false,
    this.resumePositionMs = 0,
  });

  final String uri;
  final String title;
  final MediaType type;
  final String folderPath;
  final int sizeBytes;
  final int durationMs;
  final int dateAddedMs;
  final int dateModifiedMs;
  final int? width;
  final int? height;
  final String? mimeType;
  final String? thumbPath;
  final bool isHidden;
  final bool isFavorite;
  final int resumePositionMs;

  String get folderName {
    final parts = folderPath.split('/')..removeWhere((e) => e.isEmpty);
    return parts.isEmpty ? folderPath : parts.last;
  }

  bool get hasResume =>
      resumePositionMs > 0 && durationMs > 0 && resumePositionMs < durationMs;

  MediaItem copyWith({bool? isFavorite, int? resumePositionMs}) => MediaItem(
        uri: uri,
        title: title,
        type: type,
        folderPath: folderPath,
        sizeBytes: sizeBytes,
        durationMs: durationMs,
        dateAddedMs: dateAddedMs,
        dateModifiedMs: dateModifiedMs,
        width: width,
        height: height,
        mimeType: mimeType,
        thumbPath: thumbPath,
        isHidden: isHidden,
        isFavorite: isFavorite ?? this.isFavorite,
        resumePositionMs: resumePositionMs ?? this.resumePositionMs,
      );

  @override
  List<Object?> get props => [uri];
}
