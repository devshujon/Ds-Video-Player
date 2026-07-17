import 'package:equatable/equatable.dart';

import 'vault_category.dart';

/// One file stored encrypted in the private vault.
class VaultItem extends Equatable {
  const VaultItem({
    required this.id,
    required this.vaultPath,
    required this.originalName,
    required this.type,
    required this.category,
    required this.sizeBytes,
    required this.plaintextSizeBytes,
    required this.addedAt,
    this.originalUri,
    this.durationMs = 0,
    this.thumbPath,
    this.folderPath,
  });

  final int id;
  final String vaultPath;
  final String originalName;
  final String? originalUri;

  /// Legacy type: `video | audio | image | document | other`.
  final String type;

  /// Home-screen grouping category id.
  final String category;

  /// Encrypted blob size on disk.
  final int sizeBytes;

  /// Original file size before encryption.
  final int plaintextSizeBytes;

  final int durationMs;
  final String? thumbPath;
  final String? folderPath;
  final int addedAt;

  VaultCategory get vaultCategory =>
      VaultCategory.fromId(category) ?? VaultCategory.documents;

  int get displaySizeBytes =>
      plaintextSizeBytes > 0 ? plaintextSizeBytes : sizeBytes;

  @override
  List<Object?> get props => [id];
}
