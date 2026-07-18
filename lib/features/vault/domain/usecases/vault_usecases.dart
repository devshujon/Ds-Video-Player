import '../../data/vault_repository.dart';
import '../../domain/entities/vault_item.dart';
import '../../presentation/providers/vault_provider.dart';

/// Domain use cases — thin wrappers over [VaultRepository] and [VaultProvider].
class EvaluateVault {
  EvaluateVault(this._provider);
  final VaultProvider _provider;
  Future<void> call() => _provider.evaluate();
}

class SetupVault {
  SetupVault(this._provider);
  final VaultProvider _provider;
  Future<bool> call({
    required String pin,
    required String confirmPin,
    required int pinLength,
    required bool enableBiometrics,
  }) =>
      _provider.setupVault(
        pin: pin,
        confirmPin: confirmPin,
        pinLength: pinLength,
        enableBiometrics: enableBiometrics,
      );
}

class UnlockVaultWithPin {
  UnlockVaultWithPin(this._provider);
  final VaultProvider _provider;
  Future<bool> call(String pin) => _provider.unlockWithPin(pin);
}

class LockVault {
  LockVault(this._provider);
  final VaultProvider _provider;
  void call() => _provider.lock();
}

class ListVaultItems {
  ListVaultItems(this._repo);
  final VaultRepository _repo;
  Future<List<VaultItem>> call() => _repo.list();
}
