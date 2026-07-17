import '../../../../core/constants/media_formats.dart';
import '../../../../core/utils/result.dart';
import '../entities/scan_batch.dart';
import '../entities/media_folder.dart';
import '../entities/media_item.dart';
import '../repositories/media_repository.dart';

/// Use cases keep the provider thin and the domain testable in isolation.
/// One small class per intent (Clean Architecture). They are intentionally
/// trivial pass-throughs today; business rules accrete here, not in the UI.

class ScanMedia {
  ScanMedia(this._repo);
  final MediaRepository _repo;
  Future<Result<List<MediaItem>>> call({bool force = false}) =>
      _repo.scan(force: force);
}

class ScanMediaProgressive {
  ScanMediaProgressive(this._repo);
  final MediaRepository _repo;
  Stream<Result<ScanBatch>> call() => _repo.scanProgressive();
}

class GetMediaByType {
  GetMediaByType(this._repo);
  final MediaRepository _repo;
  Future<Result<List<MediaItem>>> call(MediaType type) =>
      _repo.getByType(type);
}

class GetFolders {
  GetFolders(this._repo);
  final MediaRepository _repo;
  Future<Result<List<MediaFolder>>> call() => _repo.getFolders();
}

class GetFavorites {
  GetFavorites(this._repo);
  final MediaRepository _repo;
  Future<Result<List<MediaItem>>> call() => _repo.getFavorites();
}

class GetRecentlyPlayed {
  GetRecentlyPlayed(this._repo);
  final MediaRepository _repo;
  Future<Result<List<MediaItem>>> call() => _repo.getRecentlyPlayed();
}

class GetHidden {
  GetHidden(this._repo);
  final MediaRepository _repo;
  Future<Result<List<MediaItem>>> call() => _repo.getHidden();
}

class SearchMedia {
  SearchMedia(this._repo);
  final MediaRepository _repo;
  Future<Result<List<MediaItem>>> call(String q) => _repo.search(q);
}

class ToggleFavorite {
  ToggleFavorite(this._repo);
  final MediaRepository _repo;
  Future<Result<void>> call(String uri) => _repo.toggleFavorite(uri);
}

class SaveResume {
  SaveResume(this._repo);
  final MediaRepository _repo;
  Future<Result<void>> call({
    required String uri,
    required int positionMs,
    required int durationMs,
  }) =>
      _repo.saveResume(uri: uri, positionMs: positionMs, durationMs: durationMs);
}

class RemoveMedia {
  RemoveMedia(this._repo);
  final MediaRepository _repo;
  Future<Result<void>> call(String uri) => _repo.removeMedia(uri);
}
