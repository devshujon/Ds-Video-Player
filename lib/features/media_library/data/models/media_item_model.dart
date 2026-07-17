import '../../../../core/constants/media_formats.dart';
import '../../domain/entities/media_item.dart';

/// Maps between the SQLite row and the domain [MediaItem].
class MediaItemModel {
  const MediaItemModel._();

  static Map<String, Object?> toRow(MediaItem m) => {
        'uri': m.uri,
        'title': m.title,
        'type': m.type.name,
        'folder_path': m.folderPath,
        'size_bytes': m.sizeBytes,
        'duration_ms': m.durationMs,
        'width': m.width,
        'height': m.height,
        'mime_type': m.mimeType,
        'date_added': m.dateAddedMs,
        'date_modified': m.dateModifiedMs,
        'thumb_path': m.thumbPath,
        'is_hidden': m.isHidden ? 1 : 0,
      };

  static MediaItem fromRow(
    Map<String, Object?> row, {
    bool isFavorite = false,
    int resumePositionMs = 0,
  }) {
    return MediaItem(
      uri: row['uri'] as String,
      title: row['title'] as String,
      type: MediaType.values.firstWhere(
        (t) => t.name == row['type'],
        orElse: () => MediaType.video,
      ),
      folderPath: row['folder_path'] as String,
      sizeBytes: (row['size_bytes'] as int?) ?? 0,
      durationMs: (row['duration_ms'] as int?) ?? 0,
      width: row['width'] as int?,
      height: row['height'] as int?,
      mimeType: row['mime_type'] as String?,
      dateAddedMs: (row['date_added'] as int?) ?? 0,
      dateModifiedMs: (row['date_modified'] as int?) ?? 0,
      thumbPath: row['thumb_path'] as String?,
      isHidden: (row['is_hidden'] as int?) == 1,
      isFavorite: isFavorite,
      resumePositionMs: resumePositionMs,
    );
  }
}
