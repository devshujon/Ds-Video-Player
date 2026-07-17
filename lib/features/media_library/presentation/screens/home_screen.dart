import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../ads/presentation/widgets/banner_ad_view.dart';
import '../providers/media_library_provider.dart';
import 'audio_tab.dart';
import 'downloads_tab.dart';
import 'favorites_tab.dart';
import 'folders_tab.dart';
import 'hidden_tab.dart';
import 'video_tab.dart';

/// MX Player-style library shell with six primary tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _labels = [
    'Videos',
    'Folders',
    'Audio',
    'Downloads',
    'Favorites',
    'Hidden',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _labels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
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
          _SortButton(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, Routes.settings),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final l in _labels) Tab(text: l)],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                VideoTab(),
                FoldersTab(),
                AudioTab(),
                DownloadsTab(),
                FavoritesTab(),
                HiddenTab(),
              ],
            ),
          ),
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
