import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/media_item.dart';
import '../providers/media_library_provider.dart';
import 'media_tile.dart';

enum LibraryFilter { all, hd, large, longFiles }

/// Shared MX-style library chrome: search, sort, filter, grid/list toggle.
class LibraryTabScaffold extends StatefulWidget {
  const LibraryTabScaffold({
    super.key,
    required this.items,
    required this.onTap,
    this.onFavorite,
    this.emptyLabel = 'Nothing here yet',
    this.showTypeBadge = false,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onTap;
  final void Function(MediaItem item)? onFavorite;
  final String emptyLabel;
  final bool showTypeBadge;

  @override
  State<LibraryTabScaffold> createState() => _LibraryTabScaffoldState();
}

class _LibraryTabScaffoldState extends State<LibraryTabScaffold> {
  String _query = '';
  LibraryFilter _filter = LibraryFilter.all;

  List<MediaItem> get _filtered {
    var list = widget.items;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((i) => i.title.toLowerCase().contains(q))
          .toList(growable: false);
    }
    switch (_filter) {
      case LibraryFilter.all:
        return list;
      case LibraryFilter.hd:
        return list
            .where((i) => (i.height ?? 0) >= 720)
            .toList(growable: false);
      case LibraryFilter.large:
        return list
            .where((i) => i.sizeBytes > 500 * 1024 * 1024)
            .toList(growable: false);
      case LibraryFilter.longFiles:
        return list
            .where((i) => i.durationMs > 3600 * 1000)
            .toList(growable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<MediaLibraryProvider>();
    final items = _filtered;
    final isGrid = lib.viewMode == LibraryViewMode.grid;

    if (items.isEmpty && lib.status != LibraryStatus.scanning) {
      return Column(
        children: [
          _Toolbar(
            query: _query,
            filter: _filter,
            onQueryChanged: (v) => setState(() => _query = v),
            onFilterChanged: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: Center(child: Text(widget.emptyLabel)),
          ),
        ],
      );
    }

    return Column(
      children: [
        _Toolbar(
          query: _query,
          filter: _filter,
          onQueryChanged: (v) => setState(() => _query = v),
          onFilterChanged: (f) => setState(() => _filter = f),
        ),
        if (lib.status == LibraryStatus.scanning)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: isGrid
              ? GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.35,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return RepaintBoundary(
                      child: MediaTile(
                        item: item,
                        grid: true,
                        onFavorite: widget.onFavorite == null
                            ? null
                            : () => widget.onFavorite!(item),
                        onTap: () => widget.onTap(item, i),
                      ),
                    );
                  },
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return RepaintBoundary(
                      child: MediaTile(
                        item: item,
                        onFavorite: widget.onFavorite == null
                            ? null
                            : () => widget.onFavorite!(item),
                        onTap: () => widget.onTap(item, i),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.query,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  final String query;
  final LibraryFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<LibraryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: SearchBar(
              hintText: 'Search',
              leading: const Icon(Icons.search, size: 20),
              onChanged: onQueryChanged,
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          PopupMenuButton<LibraryFilter>(
            icon: const Icon(Icons.filter_list),
            initialValue: filter,
            onSelected: onFilterChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(value: LibraryFilter.all, child: Text('All')),
              PopupMenuItem(value: LibraryFilter.hd, child: Text('HD (720p+)')),
              PopupMenuItem(
                  value: LibraryFilter.large, child: Text('Large (500MB+)')),
              PopupMenuItem(
                  value: LibraryFilter.longFiles,
                  child: Text('Long (1hr+)')),
            ],
          ),
        ],
      ),
    );
  }
}
