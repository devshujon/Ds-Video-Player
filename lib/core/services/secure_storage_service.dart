import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import 'premium_token_store.dart';

/// Keystore-backed secrets: PIN hash, vault key, premium token.
/// Nothing sensitive is ever placed in SQLite or shared_preferences.
class SecureStorageService implements PremiumTokenStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  // --- Vault PIN ---
  Future<bool> get hasPin async =>
      await _storage.read(key: AppConstants.kPinHash) != null;

  Future<void> setPin(String pin) =>
      _storage.write(key: AppConstants.kPinHash, value: _hash(pin));

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: AppConstants.kPinHash);
    return stored != null && stored == _hash(pin);
  }

  Future<void> clearPin() async {
    await _storage.delete(key: AppConstants.kPinHash);
    await _storage.delete(key: AppConstants.kVaultPinLength);
  }

  Future<int> get pinLength async {
    final raw = await _storage.read(key: AppConstants.kVaultPinLength);
    final parsed = int.tryParse(raw ?? '');
    return parsed == 6 ? 6 : 4;
  }

  Future<void> setPinLength(int length) => _storage.write(
        key: AppConstants.kVaultPinLength,
        value: length.toString(),
      );

  Future<bool> get biometricsEnabled async =>
      (await _storage.read(key: AppConstants.kVaultBiometrics)) == '1';

  Future<void> setBiometricsEnabled(bool enabled) => _storage.write(
        key: AppConstants.kVaultBiometrics,
        value: enabled ? '1' : '0',
      );

  // --- Premium entitlement token (signed payload cached for offline) ---
  @override
  Future<void> writePremiumToken(String token) =>
      _storage.write(key: AppConstants.kPremiumToken, value: token);

  @override
  Future<String?> readPremiumToken() =>
      _storage.read(key: AppConstants.kPremiumToken);

  // --- Vault AES key (generated once, used to encrypt vault blobs) ---
  Future<String> getOrCreateVaultKey() async {
    var key = await _storage.read(key: AppConstants.kVaultKey);
    if (key == null) {
      key = _hash('${DateTime.now().microsecondsSinceEpoch}-vault-seed');
      await _storage.write(key: AppConstants.kVaultKey, value: key);
    }
    return key;
  }

  Future<void> wipe() => _storage.deleteAll();
}
