import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../ads/presentation/widgets/banner_ad_view.dart';
import '../home_navigation.dart';
import '../providers/media_library_provider.dart';
import 'audio_tab.dart';
import 'downloads_tab.dart';
import 'favorites_tab.dart';
import 'folders_tab.dart';
import 'hidden_tab.dart';
import 'home_dashboard.dart';
import 'video_tab.dart';

/// MX Player-style library shell.
///
/// Fresh launches always land on [HomeDashboard]. Library tabs open only after
/// an explicit tap. Tab selection survives background resume for the current
/// session but is never restored across process death.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final HomeNavigationState _nav = HomeNavigationState();

  TabController? _tabs;

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

  bool get _onDashboard => _nav.onDashboard;

  TabController get _tabController {
    return _tabs ??= TabController(
      length: _labels.length,
      vsync: this,
      initialIndex: _nav.activeLibraryTab ?? 0,
    );
  }

  void _selectLibraryTab(int index) {
    setState(() {
      _nav.selectLibraryTab(index);
      final controller = _tabController;
      if (controller.index != index) {
        controller.animateTo(index);
      }
    });
  }

  void _goToDashboard() {
    if (_onDashboard) return;
    setState(() {
      _nav.goToDashboard();
      _tabs?.dispose();
      _tabs = null;
    });
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onVideosTab = _nav.activeLibraryTab == 0;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          key: const Key('home_shell_title'),
          onTap: _onDashboard ? null : _goToDashboard,
          child: Text(
            _onDashboard ? AppConstants.appName : _labels[_nav.activeLibraryTab!],
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
          child: _onDashboard
              ? _DashboardTabStrip(
                  labels: _labels,
                  onTap: _selectLibraryTab,
                )
              : TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  onTap: _selectLibraryTab,
                  tabs: [for (final l in _labels) Tab(text: l)],
                ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _onDashboard
                ? const HomeDashboard(key: Key('home_dashboard'))
                : IndexedStack(
                    index: _nav.activeLibraryTab!,
                    children: _tabBodies,
                  ),
          ),
          const SafeArea(top: false, child: BannerAdView()),
        ],
      ),
    );
  }
}

/// Tab labels with no selected state — used on the Home Dashboard so Videos
/// is never highlighted at launch (TabController always starts at index 0).
class _DashboardTabStrip extends StatelessWidget {
  const _DashboardTabStrip({
    required this.labels,
    required this.onTap,
  });

  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );

    return Material(
      color: Theme.of(context).appBarTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (context, index) {
            return InkWell(
              onTap: () => onTap(index),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(labels[index], style: style),
              ),
            );
          },
        ),
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
