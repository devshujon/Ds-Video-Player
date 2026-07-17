import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/media_formats.dart';
import '../../../media_library/presentation/providers/media_library_provider.dart';
import '../../../media_library/presentation/widgets/media_tile.dart';
import '../../../player/domain/entities/playback_args.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: Consumer<MediaLibraryProvider>(
        builder: (context, lib, _) {
          if (lib.favorites.isEmpty) {
            return const Center(
              child: Text('Tap the heart on any media to save it here'),
            );
          }
          return ListView.builder(
            itemCount: lib.favorites.length,
            itemBuilder: (context, i) {
              final item = lib.favorites[i];
              return MediaTile(
                item: item,
                onFavorite: () => lib.toggleFavorite(item),
                onTap: () => Navigator.pushNamed(
                  context,
                  item.type == MediaType.audio
                      ? Routes.audioPlayer
                      : Routes.videoPlayer,
                  arguments:
                      PlaybackArgs(queue: lib.favorites, startIndex: i),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
