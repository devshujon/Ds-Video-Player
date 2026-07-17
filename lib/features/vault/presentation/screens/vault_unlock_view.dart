import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/vault_provider.dart';
import '../widgets/vault_glass_card.dart';
import '../widgets/vault_pin_input.dart';

class VaultUnlockView extends StatefulWidget {
  const VaultUnlockView({super.key});

  @override
  State<VaultUnlockView> createState() => _VaultUnlockViewState();
}

class _VaultUnlockViewState extends State<VaultUnlockView> {
  String _pin = '';
  String? _error;
  int _shakeKey = 0;
  bool _bioAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoBiometric());
  }

  Future<void> _autoBiometric() async {
    if (_bioAttempted || !mounted) return;
    final vault = context.read<VaultProvider>();
    if (!vault.canUseBiometrics) return;
    _bioAttempted = true;
    final result = await vault.unlockWithBiometric(silent: true);
    if (!mounted) return;
    if (result == VaultUnlockResult.failed) {
      setState(() => _error = 'Biometric failed — use your PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.brandPrimary.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
            child: const Icon(Icons.lock_rounded, size: 72, color: AppColors.brandAccent),
          ),
          const SizedBox(height: 18),
          Text(
            'Unlock Private Vault',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            vault.canUseBiometrics
                ? 'Use fingerprint or enter your PIN'
                : 'Enter your vault PIN to continue',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 28),
          VaultGlassCard(
            child: Column(
              children: [
                if (vault.canUseBiometrics) ...[
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final result =
                          await vault.unlockWithBiometric();
                      if (!mounted) return;
                      if (result == VaultUnlockResult.failed) {
                        setState(() {
                          _error = 'Biometric failed — use your PIN';
                          _shakeKey++;
                        });
                      }
                    },
                    icon: Icon(
                      vault.supportsFace && !vault.supportsFingerprint
                          ? Icons.face_rounded
                          : Icons.fingerprint,
                    ),
                    label: Text(vault.biometricUnlockLabel),
                  ),
                  const SizedBox(height: 18),
                  Text('Or enter PIN', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 12),
                ],
                VaultPinInput(
                  length: 4,
                  shakeKey: _shakeKey,
                  errorText: _error,
                  onChanged: (v) => setState(() {
                    _pin = v;
                    _error = null;
                  }),
                  onCompleted: (_) => _unlockWithPin(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _pin.length >= 4 ? _unlockWithPin : null,
                  child: const Text('Unlock'),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showForgotPin(context),
            child: const Text('Forgot PIN?'),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockWithPin() async {
    final ok = await context.read<VaultProvider>().unlockWithPin(_pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = 'Incorrect PIN';
        _shakeKey++;
        _pin = '';
      });
    }
  }

  Future<void> _showForgotPin(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset vault?'),
        content: const Text(
          'Forgot PIN will permanently delete all vaulted files and let you create a new vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset vault'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<VaultProvider>().resetVault();
    }
  }
}
