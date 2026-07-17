import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/media_formats.dart';
import '../../../media_library/domain/entities/media_item.dart';
import '../../../media_library/presentation/providers/media_library_provider.dart';
import '../../../media_library/presentation/widgets/media_tile.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../../data/recommendation_source.dart';
import '../../domain/recommender.dart';
import '../providers/recommendations_provider.dart';

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecommendationsProvider(
        sl<RecommendationSource>(),
        sl<Recommender>(),
      )..load(),
      child: const _RecommendationsView(),
    );
  }
}

class _RecommendationsView extends StatelessWidget {
  const _RecommendationsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggested for you')),
      body: Consumer<RecommendationsProvider>(
        builder: (context, rec, _) {
          if (rec.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rec.ranked.isEmpty) {
            return const _EmptyView();
          }

          // Resolve scored URIs against the scanned library.
          final lib = context.read<MediaLibraryProvider>();
          final byUri = {
            for (final m in [...lib.videos, ...lib.audios]) m.uri: m,
          };
          final items = <MediaItem>[
            for (final s in rec.ranked)
              if (byUri[s.uri] != null) byUri[s.uri]!,
          ];

          if (items.isEmpty) {
            return const _EmptyView();
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return MediaTile(
                item: item,
                onFavorite: () => lib.toggleFavorite(item),
                onTap: () => Navigator.pushNamed(
                  context,
                  item.type == MediaType.audio
                      ? Routes.audioPlayer
                      : Routes.videoPlayer,
                  arguments: PlaybackArgs(queue: items, startIndex: i),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 48),
          const SizedBox(height: 8),
          const Text('No suggestions yet'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Play and favourite a few things — suggestions are learned '
              'on-device from what you watch.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
