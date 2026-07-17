import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../media_library/presentation/providers/media_library_provider.dart';

/// Branded splash — permissions + cache load only. Scan runs on home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final lib = context.read<MediaLibraryProvider>();

    // Permissions and cache load in parallel — both must finish before home.
    await Future.wait([
      sl<PermissionService>().requestMediaAccess(),
      lib.loadFromCache(),
    ]);

    if (!mounted) return;

    // Scan begins immediately; home renders cached/skeleton content while it runs.
    lib.startBackgroundScan();
    Navigator.of(context).pushReplacementNamed(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.brandDark : AppColors.lightBackground,
      body: Semantics(
        label: 'Loading ${AppConstants.appName}',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/app_icon.png',
                width: 96,
                height: 96,
                semanticLabel: '${AppConstants.appName} logo',
              ),
              const SizedBox(height: 20),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: isDark
                          ? AppColors.brandWhite
                          : AppColors.brandDark,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
