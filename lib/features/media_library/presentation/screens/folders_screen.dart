import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../providers/media_library_provider.dart';
import '../widgets/media_tile.dart';

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      body: Consumer<MediaLibraryProvider>(
        builder: (context, lib, _) {
          if (lib.folders.isEmpty) {
            return const Center(child: Text('No folders'));
          }
          return ListView.builder(
            itemCount: lib.folders.length,
            itemBuilder: (context, i) {
              final f = lib.folders[i];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(f.name),
                subtitle: Text('${f.itemCount} videos · ${f.path}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FolderContents(path: f.path),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FolderContents extends StatelessWidget {
  const _FolderContents({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<MediaLibraryProvider>();
    final items = lib.itemsInFolder(path);
    return Scaffold(
      appBar: AppBar(title: Text(path.split('/').last)),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => MediaTile(
          item: items[i],
          onFavorite: () => lib.toggleFavorite(items[i]),
          onTap: () => Navigator.pushNamed(
            context,
            Routes.videoPlayer,
            arguments: PlaybackArgs(queue: items, startIndex: i),
          ),
        ),
      ),
    );
  }
}
