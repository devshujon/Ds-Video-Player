import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../../../vault/presentation/utils/vault_lock_helper.dart';
import '../../domain/entities/media_folder.dart';
import '../providers/media_library_provider.dart';
import '../widgets/media_tile.dart';

class FoldersTab extends StatefulWidget {
  const FoldersTab({super.key});

  @override
  State<FoldersTab> createState() => _FoldersTabState();
}

class _FoldersTabState extends State<FoldersTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaLibraryProvider>(
      builder: (context, lib, _) {
        var folders =
            lib.folders.where((f) => !f.isHidden).toList(growable: true);
        final q = _query.trim().toLowerCase();
        if (q.isNotEmpty) {
          folders = folders
              .where((f) =>
                  f.name.toLowerCase().contains(q) ||
                  f.path.toLowerCase().contains(q))
              .toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SearchBar(
                hintText: 'Search folders',
                leading: const Icon(Icons.search, size: 20),
                onChanged: (v) => setState(() => _query = v),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            if (lib.status == LibraryStatus.scanning)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: folders.isEmpty
                  ? const Center(child: Text('No folders'))
                  : ListView.builder(
                      itemCount: folders.length,
                      itemBuilder: (context, i) =>
                          _FolderTile(folder: folders[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder});
  final MediaFolder folder;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<MediaLibraryProvider>();
    return ListTile(
      leading: const Icon(Icons.folder_rounded),
      title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${folder.itemCount} videos',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FolderContents(path: folder.path),
        ),
      ),
      onLongPress: () {
        final items = lib.itemsInFolder(folder.path);
        if (items.isEmpty) return;
        VaultLockHelper.showFolderLockSheet(context, folder.path, items);
      },
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
      floatingActionButton: items.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () =>
                  VaultLockHelper.showFolderLockSheet(context, path, items),
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Lock folder'),
            )
          : null,
    );
  }
}
