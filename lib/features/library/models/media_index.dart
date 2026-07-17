import 'package:equatable/equatable.dart';

/// One row in the local incremental-scan index.
///
/// Uniqueness is by [path]. Delta detection on subsequent scans compares
/// [modifiedAt] + [size] against the device snapshot; an item is treated as
/// changed when either differs, and as removed when the index has a path
/// the device snapshot no longer contains.
///
/// [indexedAt] is the epoch ms at which we *first added this path to our
/// local index* — that is what powers the "Recently Added" row on the
/// library screen (device [modifiedAt] is the file mtime, which doesn't
/// distinguish "new to the user" from "old file just discovered").
class MediaIndex extends Equatable {
  const MediaIndex({
    this.id,
    required this.path,
    required this.filename,
    required this.modifiedAt,
    required this.size,
    required this.durationMs,
    required this.mediaType,
    required this.indexedAt,
    this.thumbnailPath,
  });

  /// SQLite row id. `null` for records constructed before first persist.
  final int? id;
  final String path;
  final String filename;

  /// File modification time, epoch ms.
  final int modifiedAt;

  /// File size, bytes.
  final int size;

  final int durationMs;

  /// `'video'`, `'audio'`, or `'image'`. Plain string keeps the model
  /// independent of presentation-layer enums.
  final String mediaType;

  final String? thumbnailPath;

  /// When this record was first inserted into the local index, epoch ms.
  final int indexedAt;

  MediaIndex copyWith({
    int? id,
    String? path,
    String? filename,
    int? modifiedAt,
    int? size,
    int? durationMs,
    String? mediaType,
    String? thumbnailPath,
    int? indexedAt,
  }) =>
      MediaIndex(
        id: id ?? this.id,
        path: path ?? this.path,
        filename: filename ?? this.filename,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        size: size ?? this.size,
        durationMs: durationMs ?? this.durationMs,
        mediaType: mediaType ?? this.mediaType,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        indexedAt: indexedAt ?? this.indexedAt,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'path': path,
        'filename': filename,
        'modified_at': modifiedAt,
        'size': size,
        'duration_ms': durationMs,
        'media_type': mediaType,
        'thumbnail_path': thumbnailPath,
        'indexed_at': indexedAt,
      };

  factory MediaIndex.fromRow(Map<String, Object?> row) => MediaIndex(
        id: row['id'] as int?,
        path: row['path'] as String,
        filename: row['filename'] as String,
        modifiedAt: row['modified_at'] as int,
        size: row['size'] as int,
        durationMs: (row['duration_ms'] as int?) ?? 0,
        mediaType: row['media_type'] as String,
        thumbnailPath: row['thumbnail_path'] as String?,
        indexedAt: row['indexed_at'] as int,
      );

  @override
  List<Object?> get props => [path];
}
