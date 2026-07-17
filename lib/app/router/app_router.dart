import 'package:flutter/material.dart';

import '../../core/widgets/route_error_screen.dart';
import '../../features/duplicates/presentation/screens/duplicate_finder_screen.dart';
import '../../features/equalizer/presentation/screens/equalizer_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/media_library/presentation/screens/folders_screen.dart';
import '../../features/media_library/presentation/screens/home_screen.dart';
import '../../features/photos/presentation/screens/photo_viewer_screen.dart';
import '../../features/player/domain/entities/playback_args.dart';
import '../../features/player/presentation/screens/audio_player_screen.dart';
import '../../features/player/presentation/screens/video_player_screen.dart';
import '../../features/playlists/domain/entities/playlist.dart';
import '../../features/playlists/presentation/screens/playlist_detail_screen.dart';
import '../../features/playlists/presentation/screens/playlists_screen.dart';
import '../../features/premium/presentation/screens/premium_screen.dart';
import '../../features/recommendations/presentation/screens/recommendations_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/storage/presentation/screens/storage_cleaner_screen.dart';
import '../../features/streaming/presentation/screens/stream_url_screen.dart';
import '../../features/vault/presentation/screens/vault_screen.dart';
import '../../core/utils/safe_route_args.dart';
import 'route_names.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case Routes.splash:
        page = const SplashScreen();
      case Routes.home:
        page = const HomeScreen();
      case Routes.folders:
        page = const FoldersScreen();
      case Routes.favorites:
        page = const FavoritesScreen();
      case Routes.library:
        page = const LibraryScreen();
      case Routes.playlists:
        page = const PlaylistsScreen();
      case Routes.playlistDetail:
        final playlist = routeArg<Playlist>(settings);
        page = playlist == null
            ? const RouteErrorScreen(message: 'Playlist not found.')
            : PlaylistDetailScreen(playlist: playlist);
      case Routes.search:
        page = const SearchScreen();
      case Routes.settings:
        page = const SettingsScreen();
      case Routes.premium:
        page = const PremiumScreen();
      case Routes.vault:
        page = const VaultScreen();
      case Routes.equalizer:
        page = const EqualizerScreen();
      case Routes.duplicates:
        page = const DuplicateFinderScreen();
      case Routes.storageCleaner:
        page = const StorageCleanerScreen();
      case Routes.streamUrl:
        page = const StreamUrlScreen();
      case Routes.recommendations:
        page = const RecommendationsScreen();
      case Routes.videoPlayer:
        final args = routeArg<PlaybackArgs>(settings);
        page = args == null
            ? const RouteErrorScreen(message: 'Video playback args missing.')
            : VideoPlayerScreen(args: args);
      case Routes.audioPlayer:
        page = AudioPlayerScreen(args: routeArg<PlaybackArgs>(settings));
      case Routes.photoViewer:
        final photoArgs = routeArg<PhotoViewerArgs>(settings);
        page = photoArgs == null
            ? const RouteErrorScreen(message: 'Photo viewer args missing.')
            : PhotoViewerScreen(args: photoArgs);
      default:
        page = const SplashScreen();
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
