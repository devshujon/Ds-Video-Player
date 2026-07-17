import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/services/secure_storage_service.dart';
import '../../../media_library/domain/entities/media_item.dart';
import '../../../media_library/domain/usecases/library_usecases.dart';
import '../../data/vault_repository.dart';
import '../../domain/entities/vault_category.dart';
import '../../domain/entities/vault_item.dart';

enum VaultState { locked, unlocked, needsSetup }

enum VaultBiometricAvailability { unknown, available, unavailable }

/// App-scoped vault state: auth, contents, and lock-from-library actions.
class VaultProvider extends ChangeNotifier {
  VaultProvider(
    this._secure,
    this._repo,
    this._removeMedia,
  );

  final SecureStorageService _secure;
  final VaultRepository _repo;
  final RemoveMedia _removeMedia;
  final LocalAuthentication _auth = LocalAuthentication();

  bool _disposed = false;

  VaultState state = VaultState.locked;
  List<VaultItem> items = const [];
  Map<String, int> categoryCounts = const {};

  bool isImporting = false;
  bool isExporting = false;
  bool isLoading = false;
  double importProgress = 0.0;
  String? errorText;

  bool biometricsEnabled = false;
  VaultBiometricAvailability biometricAvailability =
      VaultBiometricAvailability.unknown;

  bool get hasItems => items.isNotEmpty;

  int get totalItemCount =>
      categoryCounts.values.fold<int>(0, (a, b) => a + b);

  Future<void> evaluate() async {
    isLoading = true;
    notifyListeners();
    try {
      biometricsEnabled = await _secure.biometricsEnabled;
      await _probeBiometrics();
      state = await _secure.hasPin ? VaultState.locked : VaultState.needsSetup;
      if (state == VaultState.unlocked) {
        await _refresh();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _probeBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final enrolled = await _auth.getAvailableBiometrics();
      biometricAvailability = supported && enrolled.isNotEmpty
          ? VaultBiometricAvailability.available
          : VaultBiometricAvailability.unavailable;
    } catch (_) {
      biometricAvailability = VaultBiometricAvailability.unavailable;
    }
  }

  bool get canUseBiometrics =>
      biometricsEnabled &&
      biometricAvailability == VaultBiometricAvailability.available;

  Future<bool> setupVault({
    required String pin,
    required String confirmPin,
    required bool enableBiometrics,
  }) async {
    if (pin.length < 4 || pin != confirmPin) return false;
    await _secure.setPin(pin);
    await _secure.getOrCreateVaultKey();
    await _secure.setBiometricsEnabled(enableBiometrics);
    biometricsEnabled = enableBiometrics;
    state = VaultState.unlocked;
    await _refresh();
    return true;
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _secure.verifyPin(pin);
    if (ok) {
      state = VaultState.unlocked;
      errorText = null;
      await _refresh();
    }
    return ok;
  }

  Future<VaultUnlockResult> unlockWithBiometric({bool silent = false}) async {
    if (!canUseBiometrics) {
      return VaultUnlockResult.unavailable;
    }
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your private vault',
        biometricOnly: false,
      );
      if (ok) {
        state = VaultState.unlocked;
        errorText = null;
        await _refresh();
        return VaultUnlockResult.success;
      }
      return VaultUnlockResult.cancelled;
    } on LocalAuthException catch (e) {
      if (e.code == LocalAuthExceptionCode.userCanceled ||
          e.code == LocalAuthExceptionCode.systemCanceled) {
        return VaultUnlockResult.cancelled;
      }
      if (!silent) {
        errorText = 'Biometric authentication failed';
        notifyListeners();
      }
      return VaultUnlockResult.failed;
    } catch (_) {
      return VaultUnlockResult.failed;
    }
  }

  void lock() {
    state = VaultState.locked;
    items = const [];
    categoryCounts = const {};
    errorText = null;
    notifyListeners();
  }

  DateTime _lastActivity = DateTime.now();

  void touchActivity() => _lastActivity = DateTime.now();

  DateTime get lastActivity => _lastActivity;

  Future<void> _refresh() async {
    try {
      items = await _repo.list();
      categoryCounts = await _repo.categoryCounts();
      errorText = null;
    } catch (e) {
      errorText = 'Could not load vault: $e';
    }
    notifyListeners();
  }

  List<VaultItem> itemsForCategory(VaultCategory category) =>
      items.where((i) => i.category == category.id).toList(growable: false);

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

  Future<bool> lockFromMediaItem(MediaItem item) async {
    if (state != VaultState.unlocked) return false;
    isImporting = true;
    importProgress = 0;
    errorText = null;
    notifyListeners();
    try {
      final source = File(item.uri);
      if (!await source.exists()) {
        errorText = 'File no longer exists on device';
        return false;
      }
      await _repo.lockFromMediaItem(
        item,
        onProgress: (p) {
          importProgress = p;
          notifyListeners();
        },
      );
      await source.delete();
      await _removeMedia(item.uri);
      await _refresh();
      return true;
    } catch (e) {
      errorText = 'Could not lock file: $e';
      return false;
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
      return await _repo.exportFile(item, destination);
    } catch (e) {
      errorText = 'Export failed: $e';
      return null;
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  Future<File?> restoreItem(VaultItem item) async {
    if (state != VaultState.unlocked) return null;
    isExporting = true;
    errorText = null;
    notifyListeners();
    try {
      final restored = await _repo.restoreToOriginal(item);
      await _repo.delete(item);
      await _refresh();
      return restored;
    } catch (e) {
      errorText = 'Restore failed: $e';
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
      await _refresh();
    } catch (e) {
      errorText = 'Delete failed: $e';
      notifyListeners();
    }
  }

  Future<void> resetVault() async {
    await _repo.deleteAll();
    await _secure.clearPin();
    await _secure.setBiometricsEnabled(false);
    biometricsEnabled = false;
    items = const [];
    categoryCounts = const {};
    state = VaultState.needsSetup;
    errorText = null;
    notifyListeners();
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

enum VaultUnlockResult { success, cancelled, failed, unavailable }
