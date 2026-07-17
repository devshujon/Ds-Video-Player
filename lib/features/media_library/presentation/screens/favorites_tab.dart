import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/media_formats.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../providers/media_library_provider.dart';
import '../widgets/library_tab_scaffold.dart';

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaLibraryProvider>(
      builder: (context, lib, _) {
        return LibraryTabScaffold(
          items: lib.favorites,
          emptyLabel: 'Tap the heart on any media to save it here',
          onFavorite: lib.toggleFavorite,
          onTap: (item, i) => Navigator.pushNamed(
            context,
            item.type == MediaType.audio
                ? Routes.audioPlayer
                : Routes.videoPlayer,
            arguments: PlaybackArgs(queue: lib.favorites, startIndex: i),
          ),
        );
      },
    );
  }
}
