import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../ads/presentation/widgets/banner_ad_view.dart';
import '../providers/media_library_provider.dart';

/// Full-screen library section opened from the Home Dashboard.
/// Back returns to Home — it does not exit the app.
class LibraryPageScreen extends StatelessWidget {
  const LibraryPageScreen({
    super.key,
    required this.title,
    required this.body,
    this.showVideoActions = false,
  });

  final String title;
  final Widget body;
  final bool showVideoActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (showVideoActions) ...[
            IconButton(
              icon: Icon(
                context.watch<MediaLibraryProvider>().viewMode ==
                        LibraryViewMode.grid
                    ? Icons.view_list
                    : Icons.grid_view,
              ),
              tooltip: 'Toggle view',
              onPressed: () =>
                  context.read<MediaLibraryProvider>().toggleViewMode(),
            ),
            _SortButton(),
          ],
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, Routes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: body),
          const SafeArea(top: false, child: BannerAdView()),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MediaSort>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort',
      onSelected: (s) => context.read<MediaLibraryProvider>().setSort(s),
      itemBuilder: (_) => const [
        PopupMenuItem(value: MediaSort.dateDesc, child: Text('Newest')),
        PopupMenuItem(value: MediaSort.nameAsc, child: Text('Name')),
        PopupMenuItem(value: MediaSort.sizeDesc, child: Text('Size')),
        PopupMenuItem(value: MediaSort.durationDesc, child: Text('Duration')),
      ],
    );
  }
}
