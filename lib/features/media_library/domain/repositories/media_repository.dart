import '../../../../core/constants/media_formats.dart';
import '../../../../core/utils/result.dart';
import '../entities/scan_batch.dart';
import '../entities/media_folder.dart';
import '../entities/media_item.dart';

/// Contract the presentation layer depends on. Implemented in data/.
/// Streaming/cloud sources will implement this same interface (Phase 4).
abstract interface class MediaRepository {
  /// Full or incremental device scan; persists metadata to SQLite cache.
  Future<Result<List<MediaItem>>> scan({bool force = false});

  /// Progressive MediaStore scan — emits batches while persisting each chunk.
  Stream<Result<ScanBatch>> scanProgressive();

  /// Reads the cached library (fast path shown before a rescan completes).
  Future<Result<List<MediaItem>>> getByType(MediaType type);

  Future<Result<List<MediaFolder>>> getFolders();

  Future<Result<List<MediaItem>>> getFavorites();

  Future<Result<List<MediaItem>>> getRecentlyPlayed();

  Future<Result<List<MediaItem>>> search(String query);

  Future<Result<void>> toggleFavorite(String uri);

  Future<Result<void>> saveResume({
    required String uri,
    required int positionMs,
    required int durationMs,
  });

  Future<Result<void>> setFolderHidden(String path, bool hidden);
}
