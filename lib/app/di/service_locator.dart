import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/thumbnail_cache_service.dart';
import '../../features/ads/data/ad_service.dart';
import '../../features/library/services/library_index_store.dart';
import '../../features/library/services/library_scan_service.dart';
import '../../features/duplicates/data/duplicate_finder.dart';
import '../../features/media_library/data/datasources/media_local_datasource.dart';
import '../../features/media_library/data/datasources/media_scanner_datasource.dart';
import '../../features/media_library/data/repositories/media_repository_impl.dart';
import '../../features/media_library/domain/repositories/media_repository.dart';
import '../../features/media_library/domain/usecases/library_usecases.dart';
import '../../features/premium/data/iap_service.dart';
import '../../features/playlists/data/playlist_repository.dart';
import '../../features/vault/data/vault_repository.dart';
import '../../features/storage/data/storage_analyzer.dart';
import '../../features/streaming/data/recent_streams_store.dart';
import '../../features/recommendations/data/recommendation_source.dart';
import '../../features/recommendations/domain/recommender.dart';

final GetIt sl = GetIt.instance;

/// Builds the dependency graph once at startup. Providers (UI state) are
/// created in app.dart and pull their use cases from here.
class ServiceLocator {
  ServiceLocator._();

  static Future<void> init() async {
    // --- External / core singletons ---
    sl.registerSingleton<SharedPreferences>(
      await SharedPreferences.getInstance(),
    );
    sl.registerLazySingleton<AppDatabase>(AppDatabase.new);
    sl.registerLazySingleton<SecureStorageService>(SecureStorageService.new);
    sl.registerLazySingleton<PermissionService>(PermissionService.new);
    sl.registerLazySingleton<AdService>(AdService.new);
    sl.registerLazySingleton<ThumbnailCacheService>(ThumbnailCacheService.new);

    // --- Data sources ---
    sl.registerLazySingleton<MediaScannerDataSource>(
      () => MediaScannerDataSource(sl()),
    );
    sl.registerLazySingleton<MediaLocalDataSource>(
      () => MediaLocalDataSource(sl()),
    );

    // --- Repositories ---
    sl.registerLazySingleton<MediaRepository>(
      () => MediaRepositoryImpl(sl(), sl()),
    );
    sl.registerLazySingleton<PlaylistRepository>(
      () => PlaylistRepositoryImpl(sl<AppDatabase>()),
    );

    // --- Billing ---
    sl.registerLazySingleton<IapService>(GoogleIapService.new);
    // --- Incremental library scan ---
    sl.registerLazySingleton<LibraryIndexStore>(
      () => SqliteLibraryIndexStore(sl()),
    );
    sl.registerLazySingleton<MediaSource>(
      () => const PhotoManagerMediaSource(),
    );
    sl.registerLazySingleton<LibraryScanService>(
      () => LibraryScanService(sl<MediaSource>(), sl<LibraryIndexStore>()),
    );
    sl.registerLazySingleton<VaultRepository>(
      () => VaultRepositoryImpl(
        db: sl<AppDatabase>(),
        secure: sl<SecureStorageService>(),
      ),
    );

    // --- Library tools ---
    sl.registerLazySingleton<DuplicateFinder>(() => const DuplicateFinder());
    sl.registerLazySingleton<StorageAnalyzer>(() => const StorageAnalyzer());

    // --- Streaming ---
    sl.registerLazySingleton<RecentStreamsStore>(
      () => RecentStreamsStore(sl<SharedPreferences>()),
    );

    // --- Recommendations (on-device) ---
    sl.registerLazySingleton<RecommendationSource>(
      () => SqliteRecommendationSource(sl<AppDatabase>()),
    );
    sl.registerLazySingleton<Recommender>(() => const Recommender());

    // --- Use cases ---
    sl
      ..registerFactory(() => ScanMedia(sl()))
      ..registerFactory(() => ScanMediaProgressive(sl()))
      ..registerFactory(() => GetMediaByType(sl()))
      ..registerFactory(() => GetFolders(sl()))
      ..registerFactory(() => GetFavorites(sl()))
      ..registerFactory(() => GetRecentlyPlayed(sl()))
      ..registerFactory(() => SearchMedia(sl()))
      ..registerFactory(() => ToggleFavorite(sl()))
      ..registerFactory(() => SaveResume(sl()));
  }
}
