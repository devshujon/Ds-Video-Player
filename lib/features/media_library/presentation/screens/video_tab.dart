import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../../domain/entities/media_item.dart';
import '../providers/media_library_provider.dart';
import '../widgets/continue_watching_card.dart';
import '../widgets/library_scanning_shell.dart';
import '../widgets/media_tile.dart';
import '../../../../core/utils/formatters.dart';

class VideoTab extends StatelessWidget {
  const VideoTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaLibraryProvider>(
      builder: (context, lib, _) {
        if (lib.status == LibraryStatus.permissionDenied) {
          return const _PermissionView();
        }

        final scanning = lib.status == LibraryStatus.scanning;
        final showSkeleton = scanning && !lib.hasCachedContent;

        if (showSkeleton) {
          return const LibraryScanningShell();
        }

        if (!scanning && lib.videos.isEmpty && !lib.hasCachedContent) {
          return const _EmptyView(label: 'No videos found');
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
              if (scanning)
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
              if (continueItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: _HeroSection(
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
                              onTap: () =>
                                  _open(context, lib, item, continueItems),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (recentPlayed.isNotEmpty)
                SliverToBoxAdapter(
                  child: _HeroSection(
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
                                  _open(context, lib, item, lib.videos),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (recentlyAdded.isNotEmpty)
                SliverToBoxAdapter(
                  child: _HeroSection(
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
                                  _open(context, lib, item, lib.videos),
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
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
                                  _open(context, lib, item, lib.videos),
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
                          onTap: () => _open(context, lib, item, lib.videos),
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

  void _open(
    BuildContext context,
    MediaLibraryProvider lib,
    MediaItem item,
    List<MediaItem> queue,
  ) {
    final index = queue.indexWhere((v) => v.uri == item.uri);
    Navigator.pushNamed(
      context,
      Routes.videoPlayer,
      arguments: PlaybackArgs(
        queue: queue,
        startIndex: index < 0 ? 0 : index,
        resumePositionMs: item.resumePositionMs,
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: GlassCard(
        margin: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined,
                size: 56, color: scheme.primary),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Videos on your device will appear here automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 8),
            const Text('Media permission is required'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.read<MediaLibraryProvider>().rescan(),
              child: const Text('Grant & retry'),
            ),
          ],
        ),
      );
}
