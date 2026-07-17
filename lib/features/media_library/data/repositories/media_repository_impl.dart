import '../../../../core/constants/media_formats.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/media_folder.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/media_local_datasource.dart';
import '../datasources/media_scanner_datasource.dart';
import '../../domain/entities/scan_batch.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl(this._scanner, this._local);

  final MediaScannerDataSource _scanner;
  final MediaLocalDataSource _local;

  @override
  Future<Result<List<MediaItem>>> scan({bool force = false}) async {
    try {
      final ok = await _scanner.ensurePermission();
      if (!ok) return const FailureResult(PermissionFailure());
      final found = await _scanner.scanDevice();
      await _local.upsertAll(found);
      return Success(found);
    } catch (e) {
      return FailureResult(StorageFailure(e.toString()));
    }
  }

  @override
  Stream<Result<ScanBatch>> scanProgressive() async* {
    try {
      final ok = await _scanner.ensurePermission();
      if (!ok) {
        yield const FailureResult(PermissionFailure());
        return;
      }

      await for (final batch in _scanner.scanDeviceProgressive()) {
        if (batch.items.isNotEmpty) {
          await _local.upsertAll(batch.items);
        }
        yield Success(batch);
      }
    } catch (e) {
      yield FailureResult(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<MediaItem>>> getByType(MediaType type) =>
      _guard(() => _local.queryByType(type.name));

  @override
  Future<Result<List<MediaFolder>>> getFolders() async {
    try {
      final rows = await _local.folderCounts();
      final folders = rows
          .map((r) => MediaFolder(
                path: r['path'] as String,
                itemCount: (r['cnt'] as int?) ?? 0,
                isHidden: (r['hidden'] as int?) == 1,
              ))
          .toList();
      return Success(folders);
    } catch (e) {
      return FailureResult(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<MediaItem>>> getFavorites() =>
      _guard(_local.favorites);

  @override
  Future<Result<List<MediaItem>>> getRecentlyPlayed() =>
      _guard(_local.recentlyPlayed);

  @override
  Future<Result<List<MediaItem>>> search(String query) =>
      _guard(() => _local.search(query));

  @override
  Future<Result<void>> toggleFavorite(String uri) async {
    try {
      await _local.toggleFavorite(uri);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> saveResume({
    required String uri,
    required int positionMs,
    required int durationMs,
  }) async {
    try {
      await _local.saveResume(
        uri: uri,
        positionMs: positionMs,
        durationMs: durationMs,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> setFolderHidden(String path, bool hidden) async {
    try {
      await _local.setFolderHidden(path, hidden);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure(e.toString()));
    }
  }

  Future<Result<List<MediaItem>>> _guard(
    Future<List<MediaItem>> Function() run,
  ) async {
    try {
      return Success(await run());
    } catch (e) {
      return FailureResult(DatabaseFailure(e.toString()));
    }
  }
}
