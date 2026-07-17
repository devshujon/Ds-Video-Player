import 'package:equatable/equatable.dart';

/// One file stored encrypted in the private vault.
/// The `vault_items` SQLite row + the on-disk encrypted blob at [vaultPath]
/// together make up the item — repository operations keep the two in sync.
class VaultItem extends Equatable {
  const VaultItem({
    required this.id,
    required this.vaultPath,
    required this.originalName,
    required this.type,
    required this.sizeBytes,
    required this.addedAt,
    this.originalUri,
  });

  final int id;

  /// Absolute path to the encrypted blob in the app-private vault dir.
  final String vaultPath;

  final String originalName;
  final String? originalUri;

  /// `'video' | 'audio' | 'image' | 'other'`. Plain string — keeps the
  /// entity independent of presentation enums.
  final String type;

  final int sizeBytes;
  final int addedAt;

  @override
  List<Object?> get props => [id];
}
