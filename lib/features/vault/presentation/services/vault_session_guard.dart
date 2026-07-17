import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../providers/vault_provider.dart';

/// Observes app lifecycle and user activity to auto-lock the vault.
///
/// - Locks when the app is backgrounded or restarted (via [VaultProvider.evaluate]).
/// - Locks after [AppConstants.vaultInactivityTimeout] without interaction while unlocked.
class VaultSessionGuard extends StatefulWidget {
  const VaultSessionGuard({super.key, required this.child});

  final Widget child;

  @override
  State<VaultSessionGuard> createState() => _VaultSessionGuardState();
}

class _VaultSessionGuardState extends State<VaultSessionGuard>
    with WidgetsBindingObserver {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final vault = context.read<VaultProvider>();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (vault.state == VaultState.unlocked) {
          vault.lock();
        }
      case AppLifecycleState.resumed:
        vault.touchActivity();
        _armInactivityTimer();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onUserInteraction() {
    context.read<VaultProvider>().touchActivity();
    _armInactivityTimer();
  }

  void _armInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(AppConstants.vaultInactivityTimeout, () {
      if (!mounted) return;
      final vault = context.read<VaultProvider>();
      if (vault.state == VaultState.unlocked) {
        vault.lock();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserInteraction(),
      child: widget.child,
    );
  }
}
