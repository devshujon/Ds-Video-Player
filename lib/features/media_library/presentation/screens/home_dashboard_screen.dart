import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../ads/presentation/widgets/banner_ad_view.dart';
import 'home_dashboard.dart';

/// Standalone Home Dashboard — no library tab strip.
///
/// Navigation tree:
/// Splash → [HomeDashboardScreen] → (push) LibraryPageScreen → Back → Home
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, Routes.settings),
          ),
        ],
      ),
      body: const Column(
        children: [
          Expanded(
            child: HomeDashboard(key: Key('home_dashboard')),
          ),
          SafeArea(top: false, child: BannerAdView()),
        ],
      ),
    );
  }
}
