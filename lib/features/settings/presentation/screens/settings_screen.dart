import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../premium/presentation/providers/premium_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final settings = context.watch<SettingsProvider>();
    final premium = context.watch<PremiumProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Header('Appearance'),
          // Flutter 3.32+ RadioGroup form. The deprecated per-tile
          // `groupValue` / `onChanged` were removed; selection state and
          // the change callback now live on the surrounding RadioGroup,
          // and child RadioListTiles only carry `value` + `title`.
          RadioGroup<AppThemeMode>(
            groupValue: theme.mode,
            onChanged: (v) {
              if (v == null) return;
              final isAmoled = v == AppThemeMode.amoled;
              final locked = isAmoled &&
                  premium.isLocked(PremiumFeature.amoledTheme);
              if (locked) {
                Navigator.pushNamed(context, Routes.premium);
              } else {
                theme.setMode(v);
              }
            },
            child: Column(
              children: AppThemeMode.values.map((m) {
                final isAmoled = m == AppThemeMode.amoled;
                final locked = isAmoled &&
                    premium.isLocked(PremiumFeature.amoledTheme);
                return RadioListTile<AppThemeMode>(
                  value: m,
                  title: Text(_label(m) + (locked ? '  🔒' : '')),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          const _Header('Playback'),
          SwitchListTile(
            title: const Text('Resume from last position'),
            value: settings.resumePlayback,
            onChanged: settings.setResume,
          ),
          SwitchListTile(
            title: const Text('Background audio'),
            value: settings.backgroundAudio,
            onChanged: settings.setBackgroundAudio,
          ),
          SwitchListTile(
            title: const Text('Player gestures'),
            subtitle:
                const Text('Brightness, volume & seek swipes'),
            value: settings.gesturesEnabled,
            onChanged: settings.setGestures,
          ),
          SwitchListTile(
            title: const Text('Auto-play next'),
            value: settings.autoPlayNext,
            onChanged: settings.setAutoPlayNext,
          ),
          ListTile(
            title: const Text('Double-tap seek'),
            trailing: Text('${settings.seekSeconds}s'),
            onTap: () async {
              const steps = [5, 10, 15, 30, 60];
              final next = steps.firstWhere(
                (s) => s > settings.seekSeconds,
                orElse: () => steps.first,
              );
              await settings.setSeekSeconds(next);
            },
          ),
          SwitchListTile(
            title: const Text('Force software decode'),
            subtitle: const Text(
              'Bypass hardware decoders. Use only if videos stutter or fail '
              'to play on this device.',
            ),
            value: settings.forceSoftwareDecode,
            onChanged: settings.setForceSoftwareDecode,
          ),
          const Divider(),
          const _Header('Privacy'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Private Vault'),
            onTap: () => Navigator.pushNamed(context, Routes.vault),
          ),
          const Divider(),
          const _Header('About'),
          ListTile(
            title: const Text(AppConstants.appName),
            subtitle: const Text(
              'by ${AppConstants.brand} · v1.0.0',
            ),
            leading: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }

  String _label(AppThemeMode m) => switch (m) {
        AppThemeMode.light => 'Light',
        AppThemeMode.dark => 'Dark',
        AppThemeMode.amoled => 'AMOLED (pure black)',
      };
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
        ),
      );
}
