import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/media_library_provider.dart';
import '../widgets/media_tile.dart';
import '../widgets/video_library_common.dart';

/// Full video library — shown when the user taps the Videos tab.
class VideoTab extends StatelessWidget {
  const VideoTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaLibraryProvider>(
      builder: (context, lib, _) {
        if (lib.status == LibraryStatus.permissionDenied) {
          return const VideoLibraryPermissionView();
        }

        if (lib.videos.isEmpty) {
          return const VideoLibraryEmptyView(label: 'No videos found');
        }

        final isGrid = lib.viewMode == LibraryViewMode.grid;

        return RefreshIndicator(
          onRefresh: lib.rescan,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (lib.status == LibraryStatus.scanning)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        'All videos',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '${lib.videos.length} items',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (isGrid)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.35,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final item = lib.videos[i];
                        return RepaintBoundary(
                          child: MediaTile(
                            item: item,
                            grid: true,
                            onFavorite: () => lib.toggleFavorite(item),
                            onTap: () =>
                                openVideo(context, item, lib.videos),
                          ),
                        );
                      },
                      childCount: lib.videos.length,
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: lib.videos.length,
                  itemBuilder: (context, i) {
                    final item = lib.videos[i];
                    return RepaintBoundary(
                      child: MediaTile(
                        item: item,
                        onFavorite: () => lib.toggleFavorite(item),
                        onTap: () => openVideo(context, item, lib.videos),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
