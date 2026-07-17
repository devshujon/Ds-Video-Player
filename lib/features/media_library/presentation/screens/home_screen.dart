import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../ads/presentation/widgets/banner_ad_view.dart';
import '../../../photos/presentation/screens/photos_tab.dart';
import '../providers/media_library_provider.dart';
import 'audio_tab.dart';
import 'video_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _titles = ['Videos', 'Audio', 'Photos', 'More'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tab == 3 ? AppConstants.appName : _titles[_tab],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                Navigator.pushNamed(context, Routes.search),
          ),
          if (_tab == 0)
            IconButton(
              icon: Icon(
                context.watch<MediaLibraryProvider>().viewMode ==
                        LibraryViewMode.grid
                    ? Icons.view_list
                    : Icons.grid_view,
              ),
              onPressed: () =>
                  context.read<MediaLibraryProvider>().toggleViewMode(),
            ),
          if (_tab == 0 || _tab == 1) _SortButton(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                VideoTab(),
                AudioTab(),
                PhotosTab(),
                _MoreTab(),
              ],
            ),
          ),
          // Non-intrusive banner above the nav bar; hides for premium.
          const SafeArea(top: false, child: BannerAdView()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.video_library_outlined),
              selectedIcon: Icon(Icons.video_library),
              label: 'Videos'),
          NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music),
              label: 'Audio'),
          NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library),
              label: 'Photos'),
          NavigationDestination(
              icon: Icon(Icons.menu),
              selectedIcon: Icon(Icons.menu_open),
              label: 'More'),
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
      onSelected: (s) =>
          context.read<MediaLibraryProvider>().setSort(s),
      itemBuilder: (_) => const [
        PopupMenuItem(value: MediaSort.dateDesc, child: Text('Newest')),
        PopupMenuItem(value: MediaSort.nameAsc, child: Text('Name')),
        PopupMenuItem(value: MediaSort.sizeDesc, child: Text('Size')),
        PopupMenuItem(
            value: MediaSort.durationDesc, child: Text('Duration')),
      ],
    );
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, String)>[
      (Icons.auto_awesome_outlined, 'Suggested for you', Routes.recommendations),
      (Icons.folder_outlined, 'Folders', Routes.folders),
      (Icons.favorite_outline, 'Favorites', Routes.favorites),
      (Icons.queue_music_outlined, 'Playlists', Routes.playlists),
      (Icons.library_books_outlined, 'Library scan', Routes.library),
      (Icons.file_copy_outlined, 'Duplicate finder', Routes.duplicates),
      (Icons.cleaning_services_outlined, 'Storage cleaner',
          Routes.storageCleaner),
      (Icons.link, 'Open network URL', Routes.streamUrl),
      (Icons.lock_outline, 'Private Vault', Routes.vault),
      (Icons.equalizer, 'Equalizer', Routes.equalizer),
      (Icons.workspace_premium_outlined, 'Go Premium', Routes.premium),
      (Icons.settings_outlined, 'Settings', Routes.settings),
    ];
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final (icon, label, route) = entries[i];
        return ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, route),
        );
      },
    );
  }
}
