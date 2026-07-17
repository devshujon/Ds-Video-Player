import 'package:ds_video_player/core/constants/media_formats.dart';
import 'package:ds_video_player/core/utils/result.dart';
import 'package:ds_video_player/features/media_library/domain/entities/media_folder.dart';
import 'package:ds_video_player/features/media_library/domain/entities/media_item.dart';
import 'package:ds_video_player/features/media_library/domain/entities/scan_batch.dart';
import 'package:ds_video_player/features/media_library/domain/repositories/media_repository.dart';
import 'package:ds_video_player/features/media_library/domain/usecases/library_usecases.dart';
import 'package:ds_video_player/features/media_library/presentation/providers/media_library_provider.dart';

MediaItem testVideo({String uri = 'content://media/video/1'}) => MediaItem(
      uri: uri,
      title: 'sample.mp4',
      type: MediaType.video,
      folderPath: '/storage/Movies',
      sizeBytes: 1000000,
      durationMs: 60000,
      dateAddedMs: 1700000000000,
      dateModifiedMs: 1700000000000,
      width: 1920,
      height: 1080,
    );

class _FakeMediaRepository implements MediaRepository {
  _FakeMediaRepository({List<MediaItem>? videos}) : _videos = videos ?? [testVideo()];

  final List<MediaItem> _videos;

  @override
  Future<Result<List<MediaItem>>> scan({bool force = false}) async =>
      Success(_videos);

  @override
  Stream<Result<ScanBatch>> scanProgressive() async* {}

  @override
  Future<Result<List<MediaItem>>> getByType(MediaType type) async {
    if (type == MediaType.video) return Success(_videos);
    return const Success([]);
  }

  @override
  Future<Result<List<MediaFolder>>> getFolders() async => const Success([]);

  @override
  Future<Result<List<MediaItem>>> getFavorites() async => const Success([]);

  @override
  Future<Result<List<MediaItem>>> getRecentlyPlayed() async => const Success([]);

  @override
  Future<Result<List<MediaItem>>> getHidden() async => const Success([]);

  @override
  Future<Result<List<MediaItem>>> search(String query) async => const Success([]);

  @override
  Future<Result<void>> toggleFavorite(String uri) async => const Success(null);

  @override
  Future<Result<void>> saveResume({
    required String uri,
    required int positionMs,
    required int durationMs,
  }) async =>
      const Success(null);

  @override
  Future<Result<void>> setFolderHidden(String path, bool hidden) async =>
      const Success(null);
}

MediaLibraryProvider createTestMediaLibraryProvider({
  List<MediaItem>? videos,
}) {
  final repo = _FakeMediaRepository(videos: videos);
  final provider = MediaLibraryProvider(
    scanProgressive: ScanMediaProgressive(repo),
    getByType: GetMediaByType(repo),
    getFolders: GetFolders(repo),
    getFavorites: GetFavorites(repo),
    getRecentlyPlayed: GetRecentlyPlayed(repo),
    getHidden: GetHidden(repo),
    toggleFavorite: ToggleFavorite(repo),
  );
  provider.videos = videos ?? [testVideo()];
  provider.status = LibraryStatus.ready;
  return provider;
}
