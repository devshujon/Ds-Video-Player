import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/media_library_provider.dart';
import '../widgets/continue_watching_card.dart';
import '../widgets/library_scanning_shell.dart';
import '../widgets/media_tile.dart';
import '../widgets/video_library_common.dart';

/// Home Dashboard content — heroes and quick actions only.
/// Not embedded in VideoTab; shown by [HomeDashboardScreen].
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  static const _quickActions = [
    _QuickAction(
      label: 'Videos',
      icon: Icons.video_library_outlined,
      route: Routes.libraryVideos,
    ),
    _QuickAction(
      label: 'Folders',
      icon: Icons.folder_outlined,
      route: Routes.libraryFolders,
    ),
    _QuickAction(
      label: 'Audio',
      icon: Icons.music_note_outlined,
      route: Routes.libraryAudio,
    ),
    _QuickAction(
      label: 'Downloads',
      icon: Icons.download_outlined,
      route: Routes.libraryDownloads,
    ),
    _QuickAction(
      label: 'Favorites',
      icon: Icons.favorite_outline,
      route: Routes.libraryFavorites,
    ),
    _QuickAction(
      label: 'Hidden',
      icon: Icons.visibility_off_outlined,
      route: Routes.libraryHidden,
    ),
  ];

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

        final continueItems = lib.continueWatching;
        final recentPlayed = lib.recentlyPlayed;
        final recentlyAdded = lib.recentlyAdded;

        return RefreshIndicator(
          onRefresh: lib.rescan,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _LibrarySummary(lib: lib)),
              SliverToBoxAdapter(child: _QuickActionsGrid(actions: _quickActions)),
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
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.actions});

  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];
              return Semantics(
                button: true,
                label: 'Open ${action.label}',
                child: Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  child: InkWell(
                    key: Key('quick_action_${action.label.toLowerCase()}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => AppRouter.pushLibrary(context, action.route),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(action.icon, color: scheme.primary, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            action.label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
