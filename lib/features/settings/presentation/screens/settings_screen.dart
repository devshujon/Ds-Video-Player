import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../premium/presentation/providers/premium_provider.dart';
import '../../../player/domain/entities/player_enums.dart';
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
            subtitle: const Text('Continue playback when screen is off'),
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
          const _Header('Decoder'),
          RadioGroup<DecoderMode>(
            groupValue: settings.decoderMode,
            onChanged: (v) {
              if (v != null) settings.setDecoderMode(v);
            },
            child: Column(
              children: DecoderMode.values
                  .map(
                    (m) => RadioListTile<DecoderMode>(
                      value: m,
                      title: Text(switch (m) {
                        DecoderMode.auto => 'Auto (recommended)',
                        DecoderMode.hardware => 'Hardware decoder',
                        DecoderMode.software => 'Software decoder',
                      }),
                      subtitle: Text(switch (m) {
                        DecoderMode.auto =>
                          'Uses hardware when available, falls back safely.',
                        DecoderMode.hardware =>
                          'MediaCodec — fastest, best battery.',
                        DecoderMode.software =>
                          'CPU decode — use if videos fail or stutter.',
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(),
          const _Header('Legal & support'),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy policy'),
            subtitle: const Text('How we handle your data'),
            onTap: () => _openUrl(context, AppConstants.privacyPolicyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of use'),
            onTap: () => _openUrl(context, AppConstants.termsUrl),
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('Developer website'),
            onTap: () => _openUrl(context, AppConstants.websiteUrl),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Support'),
            subtitle: Text(AppConstants.supportEmail),
            onTap: () => _openUrl(
              context,
              'mailto:${AppConstants.supportEmail}?subject=DS%20Video%20Player%20Support',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Private Vault'),
            onTap: () => Navigator.pushNamed(context, Routes.vault),
          ),
          const Divider(),
          const _Header('About'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final version = snap.data?.version ?? '1.0.0';
              final build = snap.data?.buildNumber ?? '1';
              return ListTile(
                title: const Text(AppConstants.appName),
                subtitle: Text('by ${AppConstants.brand} · v$version ($build)'),
                leading: const Icon(Icons.info_outline),
              );
            },
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

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
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
