import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/media_formats.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../providers/media_library_provider.dart';
import '../widgets/library_tab_scaffold.dart';

class DownloadsTab extends StatelessWidget {
  const DownloadsTab({super.key});

  static bool _isDownloadPath(String path) {
    final lower = path.toLowerCase();
    return lower.contains('/download') || lower.contains('/downloads');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaLibraryProvider>(
      builder: (context, lib, _) {
        final items = [
          ...lib.videos,
          ...lib.audios,
        ].where((i) => _isDownloadPath(i.uri)).toList();

        return LibraryTabScaffold(
          items: items,
          emptyLabel: 'No downloads found',
          onFavorite: lib.toggleFavorite,
          onTap: (item, i) => Navigator.pushNamed(
            context,
            item.type == MediaType.audio
                ? Routes.audioPlayer
                : Routes.videoPlayer,
            arguments: PlaybackArgs(queue: items, startIndex: i),
          ),
        );
      },
    );
  }
}
