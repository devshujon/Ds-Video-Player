import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/media_item.dart';
import 'video_thumbnail.dart';

/// Reusable list/grid tile with async thumbnails. Wrapped in RepaintBoundary
/// by callers' builders to keep scroll at 60fps.
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onFavorite,
    this.dense = true,
    this.grid = false,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final bool dense;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    if (grid) return _GridTile(item: item, onTap: onTap, onFavorite: onFavorite);
    return _ListTile(
      item: item,
      onTap: onTap,
      onFavorite: onFavorite,
      dense: dense,
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.item,
    required this.onTap,
    this.onFavorite,
    required this.dense,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: onTap,
      leading: VideoThumbnail(
        item: item,
        width: 64,
        height: 44,
        borderRadius: 10,
        iconSize: 24,
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${Formatters.fileSize(item.sizeBytes)}'
            '${item.durationMs > 0 ? ' · ${Formatters.durationMs(item.durationMs)}' : ''}'
            '${item.width != null && item.height != null ? ' · ${item.width}×${item.height}' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (item.hasResume)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value: Formatters.progress(
                    item.resumePositionMs, item.durationMs),
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          item.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: item.isFavorite ? scheme.error : null,
          size: 20,
        ),
        onPressed: onFavorite,
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.item,
    required this.onTap,
    this.onFavorite,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoThumbnail(
                  item: item,
                  borderRadius: 14,
                  iconSize: 40,
                ),
                if (item.durationMs > 0)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        Formatters.durationMs(item.durationMs),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                if (onFavorite != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        item.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: item.isFavorite ? scheme.error : Colors.white,
                        size: 18,
                      ),
                      onPressed: onFavorite,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
