import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/vault_provider.dart';
import '../widgets/vault_glass_card.dart';
import '../widgets/vault_pin_input.dart';

class VaultCreateView extends StatefulWidget {
  const VaultCreateView({super.key});

  @override
  State<VaultCreateView> createState() => _VaultCreateViewState();
}

class _VaultCreateViewState extends State<VaultCreateView> {
  String _pin = '';
  String _confirm = '';
  bool _enableBio = true;
  String? _error;
  bool _busy = false;
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final canUseBio =
        vault.biometricAvailability == VaultBiometricAvailability.available;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _HeroIllustration(
            icon: Icons.shield_rounded,
            title: 'Create Private Vault',
            subtitle:
                'Secure your private videos and files with PIN and biometric authentication.',
          ),
          const SizedBox(height: 28),
          VaultGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _step == 0 ? 'Choose a PIN' : 'Confirm your PIN',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                VaultPinInput(
                  length: 4,
                  shakeKey: _error?.hashCode ?? 0,
                  errorText: _error,
                  onChanged: (v) => setState(() {
                    if (_step == 0) {
                      _pin = v;
                    } else {
                      _confirm = v;
                    }
                    _error = null;
                  }),
                ),
                if (_step == 0) ...[
                  const SizedBox(height: 16),
                  VaultPinStrength(pin: _pin),
                ],
                if (canUseBio) ...[
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable biometrics'),
                    subtitle: const Text('Unlock quickly with fingerprint'),
                    value: _enableBio,
                    onChanged: (v) => setState(() => _enableBio = v),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _onContinue,
                  child: Text(_step == 0 ? 'Continue' : 'Create Vault'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onContinue() async {
    if (_step == 0) {
      if (_pin.length < 4) {
        setState(() => _error = 'PIN must be at least 4 digits');
        return;
      }
      setState(() {
        _step = 1;
        _confirm = '';
        _error = null;
      });
      return;
    }

    if (_confirm != _pin) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    setState(() => _busy = true);
    final ok = await context.read<VaultProvider>().setupVault(
          pin: _pin,
          confirmPin: _confirm,
          enableBiometrics: _enableBio,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = 'Could not create vault');
    }
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.brandPrimary.withValues(alpha: 0.45),
                Colors.transparent,
              ],
            ),
          ),
          child: Icon(icon, size: 76, color: AppColors.brandAccent),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
        ),
      ],
    );
  }
}
