import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../providers/media_library_provider.dart';
import '../widgets/media_tile.dart';

class AudioTab extends StatelessWidget {
  const AudioTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaLibraryProvider>(
      builder: (context, lib, _) {
        if (lib.audios.isEmpty &&
            lib.status == LibraryStatus.scanning) {
          return const Center(child: CircularProgressIndicator());
        }
        if (lib.audios.isEmpty) {
          return const Center(child: Text('No audio files found'));
        }
        return ListView.builder(
          itemCount: lib.audios.length,
          // ignore: deprecated_member_use
          cacheExtent: 600,
          itemBuilder: (context, i) {
            final item = lib.audios[i];
            return RepaintBoundary(
              child: MediaTile(
                item: item,
                onFavorite: () => lib.toggleFavorite(item),
                onTap: () => Navigator.pushNamed(
                  context,
                  Routes.audioPlayer,
                  arguments:
                      PlaybackArgs(queue: lib.audios, startIndex: i),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
