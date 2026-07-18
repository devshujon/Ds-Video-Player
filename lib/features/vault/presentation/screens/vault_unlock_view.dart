import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/vault_provider.dart';
import '../widgets/vault_glass_card.dart';
import '../widgets/vault_numeric_keypad.dart';
import '../widgets/vault_pin_dots.dart';

class VaultUnlockView extends StatefulWidget {
  const VaultUnlockView({super.key});

  @override
  State<VaultUnlockView> createState() => _VaultUnlockViewState();
}

class _VaultUnlockViewState extends State<VaultUnlockView> {
  String _pin = '';
  String? _error;
  bool _shake = false;
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
    final pinLength = vault.pinLength;

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.brandPrimary.withValues(alpha: 0.4),
                Colors.transparent,
              ],
            ),
          ),
          child: const Icon(
            Icons.lock_rounded,
            size: 56,
            color: AppColors.brandAccent,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Unlock Private Vault',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            vault.canUseBiometrics
                ? 'Use biometrics or enter your $pinLength-digit PIN'
                : 'Enter your $pinLength-digit PIN',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(height: 24),
        if (vault.canUseBiometrics) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: VaultGlassCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: Icon(
                  vault.supportsFace && !vault.supportsFingerprint
                      ? Icons.face_rounded
                      : Icons.fingerprint,
                  color: scheme.primary,
                ),
                title: Text(vault.biometricUnlockLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final result = await vault.unlockWithBiometric();
                  if (!mounted) return;
                  if (result == VaultUnlockResult.failed) {
                    setState(() {
                      _error = 'Biometric failed — use your PIN';
                      _shake = true;
                      _pin = '';
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Or enter PIN', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 16),
        ],
        VaultPinDots(
          length: pinLength,
          filled: _pin.length,
          shake: _shake,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const Spacer(),
        VaultNumericKeypad(
          onDigit: (d) {
            if (_pin.length >= pinLength) return;
            setState(() {
              _error = null;
              _shake = false;
              _pin += d;
            });
            if (_pin.length == pinLength) {
              _unlockWithPin();
            }
          },
          onBackspace: () {
            if (_pin.isEmpty) return;
            HapticFeedback.selectionClick();
            setState(() {
              _pin = _pin.substring(0, _pin.length - 1);
              _error = null;
              _shake = false;
            });
          },
        ),
        TextButton(
          onPressed: () => _showForgotPin(context),
          child: const Text('Forgot PIN?'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _unlockWithPin() async {
    final ok = await context.read<VaultProvider>().unlockWithPin(_pin);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'Incorrect PIN';
        _shake = true;
        _pin = '';
      });
    } else {
      HapticFeedback.mediumImpact();
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
