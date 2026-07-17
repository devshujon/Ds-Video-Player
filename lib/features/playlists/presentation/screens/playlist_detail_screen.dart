import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/media_formats.dart';
import '../../../../core/utils/formatters.dart';
import '../../../media_library/domain/entities/media_item.dart';
import '../../../media_library/presentation/providers/media_library_provider.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../../data/playlist_repository.dart';
import '../../domain/entities/playlist.dart';
import '../providers/playlist_detail_provider.dart';

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          PlaylistDetailProvider(sl<PlaylistRepository>(), playlist.id)
            ..load(),
      child: _PlaylistDetailView(playlist: playlist),
    );
  }
}

class _PlaylistDetailView extends StatelessWidget {
  const _PlaylistDetailView({required this.playlist});
  final Playlist playlist;

  /// URIs → MediaItem, resolved against the scanned library. Entries the
  /// library no longer knows about resolve to null (file deleted/moved).
  Map<String, MediaItem> _libraryIndex(BuildContext context) {
    final lib = context.read<MediaLibraryProvider>();
    return {
      for (final m in [...lib.videos, ...lib.audios]) m.uri: m,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(playlist.name)),
      body: Consumer<PlaylistDetailProvider>(
        builder: (context, detail, _) {
          if (detail.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (detail.uris.isEmpty) {
            return const Center(
              child: Text('Empty playlist — tap + to add items'),
            );
          }
          final index = _libraryIndex(context);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${detail.uris.length} items',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play all'),
                      onPressed: () =>
                          _playAll(context, detail.uris, index),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: detail.uris.length,
                  onReorderItem: (oldI, newI) =>
                      context.read<PlaylistDetailProvider>().reorder(
                            oldI,
                            newI,
                          ),
                  itemBuilder: (context, i) {
                    final uri = detail.uris[i];
                    final item = index[uri];
                    return _PlaylistRow(
                      key: ValueKey(uri),
                      rowIndex: i,
                      uri: uri,
                      item: item,
                      onRemove: () => context
                          .read<PlaylistDetailProvider>()
                          .removeItem(uri),
                      onTap: item == null
                          ? null
                          : () => _playFrom(context, detail.uris, index, i),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItems(context),
        icon: const Icon(Icons.add),
        label: const Text('Add items'),
      ),
    );
  }

  void _playAll(
    BuildContext context,
    List<String> uris,
    Map<String, MediaItem> index,
  ) {
    final available = uris
        .map((u) => index[u])
        .whereType<MediaItem>()
        .toList(growable: false);
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playable items in this playlist')),
      );
      return;
    }
    _navigateToPlayer(context, available, 0);
  }

  void _playFrom(
    BuildContext context,
    List<String> uris,
    Map<String, MediaItem> index,
    int tappedIndex,
  ) {
    final available = <MediaItem>[];
    var startIndex = 0;
    for (var i = 0; i < uris.length; i++) {
      final item = index[uris[i]];
      if (item == null) continue;
      if (i == tappedIndex) startIndex = available.length;
      available.add(item);
    }
    if (available.isEmpty) return;
    _navigateToPlayer(context, available, startIndex);
  }

  void _navigateToPlayer(
    BuildContext context,
    List<MediaItem> queue,
    int startIndex,
  ) {
    final route = queue[startIndex].type == MediaType.audio
        ? Routes.audioPlayer
        : Routes.videoPlayer;
    Navigator.pushNamed(
      context,
      route,
      arguments: PlaybackArgs(queue: queue, startIndex: startIndex),
    );
  }

  Future<void> _addItems(BuildContext context) async {
    final lib = context.read<MediaLibraryProvider>();
    final detail = context.read<PlaylistDetailProvider>();
    final candidates = [...lib.videos, ...lib.audios]
        .where((m) => !detail.uris.contains(m.uri))
        .toList(growable: false);

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing left to add')),
      );
      return;
    }

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddItemsSheet(candidates: candidates),
    );
    if (selected != null && selected.isNotEmpty) {
      await detail.addItems(selected);
    }
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    super.key,
    required this.rowIndex,
    required this.uri,
    required this.item,
    required this.onRemove,
    required this.onTap,
  });

  final int rowIndex;
  final String uri;
  final MediaItem? item;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unavailable = item == null;
    return ListTile(
      onTap: onTap,
      leading: Icon(
        unavailable
            ? Icons.help_outline
            : item!.type == MediaType.audio
                ? Icons.music_note_outlined
                : Icons.movie_outlined,
      ),
      title: Text(
        unavailable ? uri.split('/').last : item!.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: unavailable
            ? TextStyle(color: Theme.of(context).disabledColor)
            : null,
      ),
      subtitle: Text(
        unavailable
            ? 'Unavailable — file moved or deleted'
            : Formatters.fileSize(item!.sizeBytes),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onRemove,
          ),
          ReorderableDragStartListener(
            index: rowIndex,
            child: const Icon(Icons.drag_handle),
          ),
        ],
      ),
    );
  }
}

class _AddItemsSheet extends StatefulWidget {
  const _AddItemsSheet({required this.candidates});
  final List<MediaItem> candidates;

  @override
  State<_AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends State<_AddItemsSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add items (${_selected.length})',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected.toList()),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: widget.candidates.length,
                itemBuilder: (context, i) {
                  final m = widget.candidates[i];
                  final checked = _selected.contains(m.uri);
                  return CheckboxListTile(
                    value: checked,
                    title: Text(
                      m.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      m.type == MediaType.audio ? 'Audio' : 'Video',
                    ),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.add(m.uri);
                      } else {
                        _selected.remove(m.uri);
                      }
                    }),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
