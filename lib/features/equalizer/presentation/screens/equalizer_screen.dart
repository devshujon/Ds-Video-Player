import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../ads/presentation/widgets/rewarded_unlock_button.dart';
import '../../../premium/presentation/providers/premium_provider.dart';

/// 10-band EQ UI + bass boost + presets. The audio-session binding
/// (Android AudioEffect / just_audio) is wired in Phase 2 (docs/04).
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  static const _bands = [
    '31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'
  ];
  final List<double> _gains = List.filled(10, 0);
  double _bass = 0;
  bool _enabled = true;
  String _preset = 'Flat';

  /// Premium presets the user temporarily unlocked this session via a
  /// rewarded ad. Cleared on app restart — intentional, the rewarded path
  /// is a session unlock, not a permanent grant.
  final Set<String> _adUnlocked = {};

  static const _presets = <String, List<double>>{
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass Boost': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
    'Treble': [0, 0, 0, 0, 0, 2, 4, 5, 6, 6],
    'Vocal': [-2, -1, 0, 2, 4, 4, 2, 0, -1, -2],
    'Rock': [4, 3, 1, 0, -1, 0, 2, 3, 4, 4],
  };

  void _applyPreset(String name) {
    final preset = _presets[name];
    if (preset == null) return;
    setState(() {
      _preset = name;
      for (var i = 0; i < 10; i++) {
        _gains[i] = preset[i];
      }
    });
  }

  /// Locked-preset sheet: offer a rewarded-ad opt-in OR a route to Premium.
  /// Both paths are user-initiated — nothing auto-fires.
  void _showLockedSheet(BuildContext context, String preset) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$preset preset is Premium',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Watch a short ad to unlock it for this session, '
                'or upgrade for unlimited access.',
              ),
              const SizedBox(height: 16),
              RewardedUnlockButton(
                label: 'Watch ad to unlock for this session',
                onReward: () {
                  setState(() {
                    _adUnlocked.add(preset);
                  });
                  _applyPreset(preset);
                  if (Navigator.canPop(sheetContext)) {
                    Navigator.pop(sheetContext);
                  }
                },
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Upgrade to Premium'),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, Routes.premium);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          Semantics(
            label: _enabled ? 'Disable equalizer' : 'Enable equalizer',
            child: Switch(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: !_enabled,
        child: Opacity(
          opacity: _enabled ? 1 : 0.4,
          child: Column(
            children: [
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  children: _presets.keys.map((name) {
                    final locked = name != 'Flat' &&
                        premium.isLocked(PremiumFeature.customEqPresets) &&
                        name == 'Rock' &&
                        !_adUnlocked.contains(name);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Semantics(
                        button: true,
                        selected: _preset == name,
                        label: '$name preset${locked ? ', locked' : ''}',
                        child: ChoiceChip(
                          label: Text(locked ? '$name 🔒' : name),
                          selected: _preset == name,
                          onSelected: (_) {
                            if (locked) {
                              _showLockedSheet(context, name);
                            } else {
                              _applyPreset(name);
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(10, (i) {
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Semantics(
                              label: '${_bands[i]} band',
                              value: '${_gains[i].round()} decibels',
                              child: Slider(
                                min: -12,
                                max: 12,
                                value: _gains[i],
                                onChanged: (v) =>
                                    setState(() => _gains[i] = v),
                              ),
                            ),
                          ),
                        ),
                        Text(_bands[i],
                            style:
                                Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Bass Boost'),
                    Expanded(
                      child: Semantics(
                        label: 'Bass boost',
                        value: '${_bass.round()} percent',
                        child: Slider(
                          value: _bass,
                          max: 100,
                          onChanged: (v) => setState(() => _bass = v),
                        ),
                      ),
                    ),
                    Text('${_bass.round()}%'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
