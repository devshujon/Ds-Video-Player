import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/services/secure_storage_service.dart';
import '../core/theme/theme_controller.dart';
import '../features/library/providers/library_provider.dart';
import '../features/library/services/library_index_store.dart';
import '../features/library/services/library_scan_service.dart';
import '../features/media_library/domain/usecases/library_usecases.dart';
import '../features/media_library/presentation/providers/media_library_provider.dart';
import '../features/photos/presentation/providers/photo_gallery_provider.dart';
import '../features/player/presentation/providers/audio_engine_provider.dart';
import '../features/playlists/data/playlist_repository.dart';
import '../features/playlists/presentation/providers/playlists_provider.dart';
import '../features/premium/data/iap_service.dart';
import '../features/premium/presentation/providers/premium_provider.dart';
import '../features/settings/presentation/providers/settings_provider.dart';
import 'di/service_locator.dart';
import 'router/app_router.dart';
import 'router/route_names.dart';

/// App root: app-scoped providers + themed MaterialApp.
/// Route-scoped providers (Player, Vault) are created at their screens.
class DSVideoPlayerApp extends StatelessWidget {
  const DSVideoPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeController(sl<SharedPreferences>()),
        ),
        ChangeNotifierProvider(
          create: (_) => PremiumProvider(
            sl<SecureStorageService>(),
            sl<IapService>(),
          )..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(sl<SharedPreferences>()),
        ),
        ChangeNotifierProvider(
          create: (_) => MediaLibraryProvider(
            scanProgressive: sl<ScanMediaProgressive>(),
            getByType: sl<GetMediaByType>(),
            getFolders: sl<GetFolders>(),
            getFavorites: sl<GetFavorites>(),
            getRecentlyPlayed: sl<GetRecentlyPlayed>(),
            toggleFavorite: sl<ToggleFavorite>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => PhotoGalleryProvider()),
        // App-scoped: audio survives navigation; foundation for mini-player.
        ChangeNotifierProvider(
          create: (_) => AudioEngineProvider(sl<SaveResume>()),
        ),
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(
            sl<LibraryScanService>(),
            sl<LibraryIndexStore>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PlaylistsProvider(sl<PlaylistRepository>()),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: theme.themeData,
            initialRoute: Routes.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
