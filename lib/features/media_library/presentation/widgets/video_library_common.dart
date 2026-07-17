import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../../domain/entities/media_item.dart';
import '../providers/media_library_provider.dart';

void openVideo(
  BuildContext context,
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

class VideoLibraryHeroSection extends StatelessWidget {
  const VideoLibraryHeroSection({
    super.key,
    required this.title,
    required this.child,
  });

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

class VideoLibraryEmptyView extends StatelessWidget {
  const VideoLibraryEmptyView({super.key, required this.label});
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

class VideoLibraryPermissionView extends StatelessWidget {
  const VideoLibraryPermissionView({super.key});

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
