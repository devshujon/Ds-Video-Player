import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/services/secure_storage_service.dart';
import '../../data/vault_repository.dart';
import '../../domain/entities/vault_item.dart';

enum VaultState { locked, unlocked, needsSetup }

/// Gates the private vault behind biometric or PIN, and owns the contents
/// of the vault once unlocked. The AES key lives in Keystore
/// (`SecureStorageService`); blobs are AES-GCM encrypted in app-private
/// storage via [VaultRepository].
class VaultProvider extends ChangeNotifier {
  VaultProvider(this._secure, this._repo);

  final SecureStorageService _secure;
  final VaultRepository _repo;
  final LocalAuthentication _auth = LocalAuthentication();

  // M1 — lifecycle guard: import/export/unlock can resolve after route pop.
  bool _disposed = false;

  VaultState state = VaultState.locked;
  List<VaultItem> items = const [];

  bool isImporting = false;
  bool isExporting = false;
  double importProgress = 0.0;
  String? errorText;

  Future<void> evaluate() async {
    state = await _secure.hasPin ? VaultState.locked : VaultState.needsSetup;
    notifyListeners();
  }

  Future<bool> setupPin(String pin) async {
    if (pin.length < 4) return false;
    await _secure.setPin(pin);
    await _secure.getOrCreateVaultKey();
    state = VaultState.unlocked;
    await _refresh();
    return true;
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _secure.verifyPin(pin);
    if (ok) {
      state = VaultState.unlocked;
      await _refresh();
    }
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    try {
      final canCheck = await _auth.canCheckBiometrics ||
          await _auth.isDeviceSupported();
      if (!canCheck) return false;
      // local_auth 3.0.1 removed `AuthenticationOptions` and the `options:`
      // param from `authenticate()`. The previously-set defaults
      // (`biometricOnly: false`, `stickyAuth: true`) match the 3.x
      // defaults, so the simpler call below preserves the same behaviour.
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your private vault',
      );
      if (ok) {
        state = VaultState.unlocked;
        await _refresh();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  void lock() {
    state = VaultState.locked;
    items = const [];
    errorText = null;
    notifyListeners();
  }

  // --- Vault contents ---

  Future<void> _refresh() async {
    try {
      items = await _repo.list();
      errorText = null;
    } catch (e) {
      errorText = 'Could not list vault: $e';
    }
    notifyListeners();
  }

  /// Encrypts [source] into the vault, leaves the original on disk. If
  /// [deleteOriginal] is true, the original is removed after a successful
  /// import.
  Future<void> importFile(
    File source, {
    bool deleteOriginal = false,
  }) async {
    if (isImporting || state != VaultState.unlocked) return;
    isImporting = true;
    importProgress = 0;
    errorText = null;
    notifyListeners();
    try {
      await _repo.importFile(
        source,
        onProgress: (p) {
          importProgress = p;
          notifyListeners();
        },
      );
      if (deleteOriginal && await source.exists()) {
        await source.delete();
      }
      await _refresh();
    } catch (e) {
      errorText = 'Import failed: $e';
    } finally {
      isImporting = false;
      importProgress = 0;
      notifyListeners();
    }
  }

  Future<File?> exportFile(VaultItem item, File destination) async {
    if (isExporting || state != VaultState.unlocked) return null;
    isExporting = true;
    errorText = null;
    notifyListeners();
    try {
      final out = await _repo.exportFile(item, destination);
      return out;
    } catch (e) {
      errorText = 'Export failed: $e';
      return null;
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  Future<void> delete(VaultItem item) async {
    if (state != VaultState.unlocked) return;
    try {
      await _repo.delete(item);
      items = items.where((i) => i.id != item.id).toList(growable: false);
      notifyListeners();
    } catch (e) {
      errorText = 'Delete failed: $e';
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
