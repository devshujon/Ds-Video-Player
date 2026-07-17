import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/formatters.dart';
import '../providers/media_library_provider.dart';
import '../widgets/continue_watching_card.dart';
import '../widgets/library_scanning_shell.dart';
import '../widgets/media_tile.dart';
import '../widgets/video_library_common.dart';

/// Default landing view — heroes, library summary, and all videos.
/// Shown on cold launch before any library tab is selected.
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaLibraryProvider>(
      builder: (context, lib, _) {
        if (lib.status == LibraryStatus.permissionDenied) {
          return const VideoLibraryPermissionView();
        }

        final scanning = lib.status == LibraryStatus.scanning;
        final showSkeleton = scanning && !lib.hasCachedContent;

        if (showSkeleton) {
          return const LibraryScanningShell();
        }

        if (!scanning && lib.videos.isEmpty && !lib.hasCachedContent) {
          return const VideoLibraryEmptyView(label: 'No videos found');
        }

        final continueItems = lib.continueWatching;
        final recentPlayed = lib.recentlyPlayed;
        final recentlyAdded = lib.recentlyAdded;
        final isGrid = lib.viewMode == LibraryViewMode.grid;

        return RefreshIndicator(
          onRefresh: lib.rescan,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _LibrarySummary(lib: lib)),
              if (scanning)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  ),
                ),
              if (continueItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: VideoLibraryHeroSection(
                    title: 'Continue watching',
                    child: SizedBox(
                      height: 168,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final item in continueItems)
                            ContinueWatchingCard(
                              item: item,
                              progress: Formatters.progress(
                                item.resumePositionMs,
                                item.durationMs,
                              ),
                              onTap: () => openVideo(
                                context,
                                item,
                                continueItems,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (recentPlayed.isNotEmpty)
                SliverToBoxAdapter(
                  child: VideoLibraryHeroSection(
                    title: 'Recent videos',
                    child: SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: recentPlayed.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final item = recentPlayed[i];
                          return SizedBox(
                            width: 160,
                            child: MediaTile(
                              item: item,
                              grid: true,
                              onTap: () =>
                                  openVideo(context, item, lib.videos),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (recentlyAdded.isNotEmpty)
                SliverToBoxAdapter(
                  child: VideoLibraryHeroSection(
                    title: 'Recently added',
                    child: SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: recentlyAdded.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final item = recentlyAdded[i];
                          return SizedBox(
                            width: 160,
                            child: MediaTile(
                              item: item,
                              grid: true,
                              onTap: () =>
                                  openVideo(context, item, lib.videos),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (lib.videos.isNotEmpty) ...[
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
            ],
          ),
        );
      },
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({required this.lib});
  final MediaLibraryProvider lib;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scanning = lib.status == LibraryStatus.scanning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.dashboard_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Library summary',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lib.videos.length} videos · '
                      '${lib.audios.length} audio · '
                      '${lib.folders.length} folders'
                      '${scanning ? ' · scanning…' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
