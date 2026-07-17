import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/playlist.dart';
import '../providers/playlists_provider.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PlaylistsProvider>().load(),
    );
  }

  Future<String?> _nameDialog({String? initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(initial == null ? 'New playlist' : 'Rename playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(initial == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final provider = context.read<PlaylistsProvider>();
          final name = await _nameDialog();
          if (name != null && name.isNotEmpty) {
            await provider.create(name);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Consumer<PlaylistsProvider>(
        builder: (context, p, _) {
          if (p.isLoading && p.playlists.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (p.playlists.isEmpty) {
            return const Center(child: Text('No playlists yet'));
          }
          return ListView.separated(
            itemCount: p.playlists.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final playlist = p.playlists[i];
              return ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(playlist.name),
                subtitle: Text(
                  '${playlist.itemCount} '
                  '${playlist.itemCount == 1 ? 'item' : 'items'}',
                ),
                onTap: () => Navigator.pushNamed(
                  context,
                  Routes.playlistDetail,
                  arguments: playlist,
                ),
                trailing: PopupMenuButton<_Action>(
                  onSelected: (a) => _onAction(context, a, playlist),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _Action.rename, child: Text('Rename')),
                    PopupMenuItem(value: _Action.delete, child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    _Action action,
    Playlist playlist,
  ) async {
    final provider = context.read<PlaylistsProvider>();
    switch (action) {
      case _Action.rename:
        final name = await _nameDialog(initial: playlist.name);
        if (name != null && name.isNotEmpty) {
          await provider.rename(playlist, name);
        }
      case _Action.delete:
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete playlist?'),
            content: Text('"${playlist.name}" will be removed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await provider.delete(playlist);
        }
    }
  }
}

enum _Action { rename, delete }
