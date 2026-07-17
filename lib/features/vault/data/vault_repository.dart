import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/media_formats.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../domain/entities/vault_item.dart';
import 'vault_crypto.dart';

abstract interface class VaultRepository {
  Future<List<VaultItem>> list();

  /// Encrypts [source] into the vault dir and inserts the row. The
  /// original file is **not** touched — caller decides whether to delete.
  Future<VaultItem> importFile(
    File source, {
    String? originalName,
    void Function(double)? onProgress,
  });

  /// Decrypts the vaulted blob to [destination], leaving the vault entry
  /// intact. Returns the written file.
  Future<File> exportFile(
    VaultItem item,
    File destination, {
    void Function(double)? onProgress,
  });

  /// Deletes the blob and the row. Idempotent for an already-missing blob.
  Future<void> delete(VaultItem item);
}

class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl({
    required AppDatabase db,
    required SecureStorageService secure,
    VaultCrypto? crypto,
  })  : _db = db,
        _secure = secure,
        _crypto = crypto ?? VaultCrypto();

  final AppDatabase _db;
  final SecureStorageService _secure;
  final VaultCrypto _crypto;

  static const String _table = 'vault_items';

  Future<Directory> _vaultDir() async {
    // App-private support dir is the right home: not user-visible, not
    // backed up by default on Android, and survives app upgrades.
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'vault'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<int>> _keyBytes() async {
    final hex = await _secure.getOrCreateVaultKey();
    return vaultKeyFromHex(hex);
  }

  @override
  Future<List<VaultItem>> list() async {
    final db = await _db.database;
    final rows = await db.query(_table, orderBy: 'added_at DESC');
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<VaultItem> importFile(
    File source, {
    String? originalName,
    void Function(double)? onProgress,
  }) async {
    final name = originalName ?? p.basename(source.path);
    final type = _classify(name);
    final dir = await _vaultDir();
    final blobName =
        '${DateTime.now().microsecondsSinceEpoch}_${_safeName(name)}.dsv';
    final blob = File(p.join(dir.path, blobName));

    await _crypto.encryptFile(
      input: source,
      output: blob,
      keyBytes: await _keyBytes(),
      onProgress: onProgress,
    );

    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert(
      _table,
      {
        'vault_path': blob.path,
        'original_name': name,
        'original_uri': source.path,
        'type': type,
        'size_bytes': await blob.length(),
        'added_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return VaultItem(
      id: id,
      vaultPath: blob.path,
      originalName: name,
      originalUri: source.path,
      type: type,
      sizeBytes: await blob.length(),
      addedAt: now,
    );
  }

  @override
  Future<File> exportFile(
    VaultItem item,
    File destination, {
    void Function(double)? onProgress,
  }) async {
    final blob = File(item.vaultPath);
    if (!await blob.exists()) {
      throw const FileSystemException('Vault blob missing');
    }
    await _crypto.decryptFile(
      input: blob,
      output: destination,
      keyBytes: await _keyBytes(),
      onProgress: onProgress,
    );
    return destination;
  }

  @override
  Future<void> delete(VaultItem item) async {
    final db = await _db.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [item.id]);
    final blob = File(item.vaultPath);
    if (await blob.exists()) {
      await blob.delete();
    }
  }

  VaultItem _fromRow(Map<String, Object?> row) => VaultItem(
        id: row['id'] as int,
        vaultPath: row['vault_path'] as String,
        originalName: row['original_name'] as String,
        originalUri: row['original_uri'] as String?,
        type: row['type'] as String,
        sizeBytes: (row['size_bytes'] as int?) ?? 0,
        addedAt: (row['added_at'] as int?) ?? 0,
      );

  String _classify(String name) {
    final type = MediaFormats.classify(name);
    return switch (type) {
      MediaType.video => 'video',
      MediaType.audio => 'audio',
      MediaType.image => 'image',
      null => 'other',
    };
  }

  /// Sanitise a name for use as a blob filename component.
  String _safeName(String name) {
    return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}
