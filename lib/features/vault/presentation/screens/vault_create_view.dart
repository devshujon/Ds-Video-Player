import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/vault_pin_validator.dart';
import '../providers/vault_provider.dart';
import '../widgets/vault_glass_card.dart';
import '../widgets/vault_numeric_keypad.dart';
import '../widgets/vault_pin_dots.dart';
import '../widgets/vault_setup_progress.dart';

enum _SetupStep { chooseLength, createPin, confirmPin, biometrics }

/// Banking-style multi-step vault PIN setup wizard.
class VaultCreateView extends StatefulWidget {
  const VaultCreateView({super.key});

  @override
  State<VaultCreateView> createState() => _VaultCreateViewState();
}

class _VaultCreateViewState extends State<VaultCreateView>
    with SingleTickerProviderStateMixin {
  _SetupStep _step = _SetupStep.chooseLength;
  int _pinLength = 4;
  String _pin = '';
  String _confirmPin = '';
  bool _pinsConfirmed = false;
  bool _showSuccess = false;
  bool _enableBio = true;
  bool _creating = false;
  String? _error;
  bool _shake = false;

  late AnimationController _successCtrl;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    super.dispose();
  }

  int get _progressIndex => switch (_step) {
        _SetupStep.chooseLength => 0,
        _SetupStep.createPin => 1,
        _SetupStep.confirmPin => 2,
        _SetupStep.biometrics => 3,
      };

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final canUseBio =
        vault.biometricAvailability == VaultBiometricAvailability.available;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: VaultSetupProgress(current: _progressIndex, total: 4),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: switch (_step) {
                _SetupStep.chooseLength => _buildChooseLength(context),
                _SetupStep.createPin => _buildPinStep(
                    context,
                    key: const ValueKey('create'),
                    title: 'Create your PIN',
                    subtitle: 'Enter a $_pinLength-digit PIN using the keypad below.',
                    pin: _pin,
                  ),
                _SetupStep.confirmPin => _buildPinStep(
                    context,
                    key: const ValueKey('confirm'),
                    title: 'Confirm your PIN',
                    subtitle: 'Enter the same PIN again to confirm.',
                    pin: _confirmPin,
                    success: _showSuccess,
                  ),
                _SetupStep.biometrics => _buildBiometricsStep(
                    context,
                    canUseBio: canUseBio,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChooseLength(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('length'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          _hero(
            icon: Icons.shield_rounded,
            title: 'Create Private Vault',
            subtitle:
                'Choose how you want to protect your private files.',
          ),
          const SizedBox(height: 24),
          _lengthOption(
            context,
            length: 4,
            title: '4-digit PIN',
            badge: 'Recommended',
            description: 'Quick to enter and easy to remember.',
            selected: _pinLength == 4,
            onTap: () => setState(() => _pinLength = 4),
          ),
          const SizedBox(height: 12),
          _lengthOption(
            context,
            length: 6,
            title: '6-digit PIN',
            badge: 'More secure',
            description: 'Stronger protection with more combinations.',
            selected: _pinLength == 6,
            onTap: () => setState(() => _pinLength = 6),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => setState(() {
              _step = _SetupStep.createPin;
              _pin = '';
              _error = null;
            }),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _lengthOption(
    BuildContext context, {
    required int length,
    required String title,
    required String badge,
    required String description,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return VaultGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: 2,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinStep(
    BuildContext context, {
    required Key key,
    required String title,
    required String subtitle,
    required String pin,
    bool success = false,
  }) {
    return Column(
      key: key,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (success)
          ScaleTransition(
            scale: _successScale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.tertiaryContainer,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 36,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          )
        else
          VaultPinDots(
            length: _pinLength,
            filled: pin.length,
            shake: _shake,
            success: success,
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const Spacer(),
        VaultNumericKeypad(
          enabled: !success && !_creating,
          onDigit: _onDigit,
          onBackspace: _onBackspace,
        ),
        const SizedBox(height: 16),
        if (_step != _SetupStep.chooseLength)
          TextButton(
            onPressed: _creating ? null : _goBack,
            child: const Text('Back'),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBiometricsStep(BuildContext context, {required bool canUseBio}) {
    final vault = context.watch<VaultProvider>();

    return SingleChildScrollView(
      key: const ValueKey('bio'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          _hero(
            icon: canUseBio ? Icons.fingerprint_rounded : Icons.lock_rounded,
            title: canUseBio
                ? 'Enable Fingerprint Unlock?'
                : 'Vault almost ready',
            subtitle: canUseBio
                ? 'Unlock quickly with ${vault.supportsFace && vault.supportsFingerprint ? 'fingerprint or face' : vault.supportsFace ? 'face recognition' : 'your fingerprint'}. You can still use your PIN anytime.'
                : 'Biometrics are not available on this device. You can unlock with your PIN.',
          ),
          const SizedBox(height: 24),
          if (canUseBio)
            VaultGlassCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(vault.biometricUnlockLabel),
                subtitle: const Text('Recommended for faster access'),
                value: _enableBio,
                onChanged: _creating
                    ? null
                    : (v) => setState(() => _enableBio = v),
              ),
            ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _pinsConfirmed && !_creating ? _createVault : null,
            child: _creating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Create Vault'),
          ),
        ],
      ),
    );
  }

  Widget _hero({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
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
          child: Icon(icon, size: 56, color: AppColors.brandAccent),
        ),
        const SizedBox(height: 16),
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

  void _onDigit(String digit) {
    if (_creating || _showSuccess) return;

    setState(() {
      _error = null;
      _shake = false;

      if (_step == _SetupStep.createPin) {
        if (_pin.length >= _pinLength) return;
        _pin += digit;
        if (_pin.length == _pinLength) {
          _onCreatePinComplete();
        }
      } else if (_step == _SetupStep.confirmPin) {
        if (_confirmPin.length >= _pinLength) return;
        _confirmPin += digit;
        if (_confirmPin.length == _pinLength) {
          _onConfirmPinComplete();
        }
      }
    });
  }

  void _onBackspace() {
    if (_creating || _showSuccess) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _shake = false;
      if (_step == _SetupStep.createPin && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else if (_step == _SetupStep.confirmPin && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  void _onCreatePinComplete() {
    final validation = VaultPinValidator.validate(_pin);
    if (validation != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = validation;
        _shake = true;
        _pin = '';
      });
      return;
    }
    HapticFeedback.mediumImpact();
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _step = _SetupStep.confirmPin;
        _confirmPin = '';
        _error = null;
      });
    });
  }

  Future<void> _onConfirmPinComplete() async {
    if (_confirmPin != _pin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'PINs do not match';
        _shake = true;
        _confirmPin = '';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _pinsConfirmed = true;
      _showSuccess = true;
      _error = null;
    });
    await _successCtrl.forward(from: 0);

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _showSuccess = false;
      _step = _SetupStep.biometrics;
      _enableBio = context.read<VaultProvider>().biometricAvailability ==
          VaultBiometricAvailability.available;
    });
  }

  void _goBack() {
    setState(() {
      _error = null;
      _shake = false;
      switch (_step) {
        case _SetupStep.createPin:
          _step = _SetupStep.chooseLength;
          _pin = '';
        case _SetupStep.confirmPin:
          _step = _SetupStep.createPin;
          _confirmPin = '';
          _pinsConfirmed = false;
        case _SetupStep.biometrics:
          _step = _SetupStep.confirmPin;
          _confirmPin = '';
          _pinsConfirmed = false;
        case _SetupStep.chooseLength:
          break;
      }
    });
  }

  Future<void> _createVault() async {
    if (!_pinsConfirmed || _creating) return;
    setState(() => _creating = true);
    HapticFeedback.mediumImpact();

    final ok = await context.read<VaultProvider>().setupVault(
          pin: _pin,
          confirmPin: _confirmPin,
          pinLength: _pinLength,
          enableBiometrics: _enableBio,
        );

    if (!mounted) return;
    setState(() => _creating = false);

    if (ok) {
      HapticFeedback.heavyImpact();
    } else {
      setState(() => _error = 'Could not create vault. Please try again.');
    }
  }
}
