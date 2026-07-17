/// Narrow persistence boundary used by [PremiumProvider] to cache the
/// entitlement token.
///
/// In production this is satisfied by `SecureStorageService` (Keystore-
/// backed). The interface keeps the provider testable without dragging in
/// `flutter_secure_storage` plugin channels.
abstract interface class PremiumTokenStore {
  Future<String?> readPremiumToken();
  Future<void> writePremiumToken(String token);
}
