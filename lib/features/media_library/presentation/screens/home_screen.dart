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
import 'home_dashboard.dart';
import 'video_tab.dart';

/// MX Player-style library shell. Cold launch lands on [HomeDashboard];
/// library tabs open only after the user taps them.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// `null` = Home Dashboard (always on fresh launch).
  /// Set when a library tab is tapped; kept for the current session only.
  int? _libraryTab;

  late final TabController _tabs;

  static const _labels = [
    'Videos',
    'Folders',
    'Audio',
    'Downloads',
    'Favorites',
    'Hidden',
  ];

  static const _tabBodies = <Widget>[
    VideoTab(),
    FoldersTab(),
    AudioTab(),
    DownloadsTab(),
    FavoritesTab(),
    HiddenTab(),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _labels.length, vsync: this);
  }

  bool get _onDashboard => _libraryTab == null;

  void _selectLibraryTab(int index) {
    setState(() => _libraryTab = index);
    _tabs.animateTo(index);
  }

  void _goToDashboard() {
    if (_onDashboard) return;
    setState(() => _libraryTab = null);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onVideosTab = _libraryTab == 0;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onDashboard ? null : _goToDashboard,
          child: Text(
            _onDashboard ? AppConstants.appName : _labels[_libraryTab!],
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        actions: [
          if (onVideosTab)
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
          if (onVideosTab) _SortButton(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, Routes.settings),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Theme(
            data: Theme.of(context).copyWith(
              tabBarTheme: _onDashboard
                  ? TabBarThemeData(
                      indicatorColor: Colors.transparent,
                      dividerColor: Colors.transparent,
                      labelColor: scheme.onSurfaceVariant,
                      unselectedLabelColor: scheme.onSurfaceVariant,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                    )
                  : null,
            ),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: _selectLibraryTab,
              tabs: [for (final l in _labels) Tab(text: l)],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _onDashboard
                ? const HomeDashboard()
                : IndexedStack(
                    index: _libraryTab!,
                    children: _tabBodies,
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
