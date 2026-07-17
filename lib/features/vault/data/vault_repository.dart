import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/media_formats.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../domain/entities/vault_category.dart';
import '../domain/entities/vault_item.dart';
import '../../media_library/domain/entities/media_item.dart';
import 'vault_crypto.dart';

abstract interface class VaultRepository {
  Future<List<VaultItem>> list();

  Future<Map<String, int>> categoryCounts();

  Future<List<VaultItem>> listByCategory(String category);

  Future<VaultItem> importFile(
    File source, {
    String? originalName,
    String? originalUri,
    String? folderPath,
    int durationMs = 0,
    String? thumbPath,
    void Function(double)? onProgress,
  });

  Future<VaultItem> lockFromMediaItem(
    MediaItem item, {
    void Function(double)? onProgress,
  });

  Future<File> exportFile(
    VaultItem item,
    File destination, {
    void Function(double)? onProgress,
  });

  Future<File> restoreToOriginal(VaultItem item);

  Future<void> delete(VaultItem item);

  Future<void> deleteAll();
}

class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl({
    required AppDatabase db,
    required SecureStorageService secure,
    VaultCrypto? crypto,
    Future<Directory> Function()? vaultDirOverride,
  })  : _db = db,
        _secure = secure,
        _crypto = crypto ?? VaultCrypto(),
        _vaultDirOverride = vaultDirOverride;

  final AppDatabase _db;
  final SecureStorageService _secure;
  final VaultCrypto _crypto;
  final Future<Directory> Function()? _vaultDirOverride;

  static const String _table = 'vault_items';

  static const Set<String> _documentExtensions = {
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx',
    'zip', 'rar', '7z', 'apk', 'json', 'xml', 'csv',
  };

  Future<Directory> _vaultDir() async {
    if (_vaultDirOverride != null) {
      final dir = await _vaultDirOverride!();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'vault'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _thumbDir() async {
    final base = _vaultDirOverride != null
        ? await _vaultDirOverride!()
        : await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'vault_thumbs'));
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
  Future<Map<String, int>> categoryCounts() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT category, COUNT(*) AS cnt FROM $_table GROUP BY category',
    );
    final counts = <String, int>{};
    for (final row in rows) {
      counts[row['category'] as String] = (row['cnt'] as int?) ?? 0;
    }
    for (final c in VaultCategory.values) {
      counts.putIfAbsent(c.id, () => 0);
    }
    return counts;
  }

  @override
  Future<List<VaultItem>> listByCategory(String category) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'added_at DESC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<VaultItem> importFile(
    File source, {
    String? originalName,
    String? originalUri,
    String? folderPath,
    int durationMs = 0,
    String? thumbPath,
    void Function(double)? onProgress,
  }) async {
    if (!await source.exists()) {
      throw const FileSystemException('Source file missing');
    }

    final name = originalName ?? p.basename(source.path);
    final uri = originalUri ?? source.path;
    final type = _classifyType(name);
    final category = _classifyCategory(
      name: name,
      path: uri,
      folderPath: folderPath,
    );
    final plaintextSize = await source.length();
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
        'original_uri': uri,
        'type': type,
        'category': category,
        'size_bytes': await blob.length(),
        'plaintext_size_bytes': plaintextSize,
        'duration_ms': durationMs,
        'thumb_path': thumbPath,
        'folder_path': folderPath,
        'added_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final copiedThumb = await _persistThumb(thumbPath, id);
    if (copiedThumb != null) {
      await db.update(
        _table,
        {'thumb_path': copiedThumb},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    return VaultItem(
      id: id,
      vaultPath: blob.path,
      originalName: name,
      originalUri: uri,
      type: type,
      category: category,
      sizeBytes: await blob.length(),
      plaintextSizeBytes: plaintextSize,
      durationMs: durationMs,
      thumbPath: copiedThumb ?? thumbPath,
      folderPath: folderPath,
      addedAt: now,
    );
  }

  @override
  Future<VaultItem> lockFromMediaItem(
    MediaItem item, {
    void Function(double)? onProgress,
  }) async {
    final source = File(item.uri);
    return importFile(
      source,
      originalName: item.title,
      originalUri: item.uri,
      folderPath: item.folderPath,
      durationMs: item.durationMs,
      thumbPath: item.thumbPath,
      onProgress: onProgress,
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
    await destination.parent.create(recursive: true);
    await _crypto.decryptFile(
      input: blob,
      output: destination,
      keyBytes: await _keyBytes(),
      onProgress: onProgress,
    );
    return destination;
  }

  @override
  Future<File> restoreToOriginal(VaultItem item) async {
    final original = item.originalUri;
    if (original == null || original.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      final dest = File(p.join(dir.path, 'restored', item.originalName));
      return exportFile(item, dest);
    }
    return exportFile(item, File(original));
  }

  @override
  Future<void> delete(VaultItem item) async {
    final db = await _db.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [item.id]);
    final blob = File(item.vaultPath);
    if (await blob.exists()) {
      await blob.delete();
    }
    if (item.thumbPath != null) {
      final thumb = File(item.thumbPath!);
      if (await thumb.exists()) {
        await thumb.delete();
      }
    }
  }

  @override
  Future<void> deleteAll() async {
    final items = await list();
    for (final item in items) {
      await delete(item);
    }
  }

  Future<String?> _persistThumb(String? thumbPath, int itemId) async {
    if (thumbPath == null) return null;
    final src = File(thumbPath);
    if (!await src.exists()) return null;
    final dir = await _thumbDir();
    final dest = File(p.join(dir.path, '$itemId${p.extension(thumbPath)}'));
    await src.copy(dest.path);
    return dest.path;
  }

  VaultItem _fromRow(Map<String, Object?> row) => VaultItem(
        id: row['id'] as int,
        vaultPath: row['vault_path'] as String,
        originalName: row['original_name'] as String,
        originalUri: row['original_uri'] as String?,
        type: row['type'] as String,
        category: (row['category'] as String?) ?? row['type'] as String,
        sizeBytes: (row['size_bytes'] as int?) ?? 0,
        plaintextSizeBytes: (row['plaintext_size_bytes'] as int?) ??
            (row['size_bytes'] as int?) ??
            0,
        durationMs: (row['duration_ms'] as int?) ?? 0,
        thumbPath: row['thumb_path'] as String?,
        folderPath: row['folder_path'] as String?,
        addedAt: (row['added_at'] as int?) ?? 0,
      );

  String _classifyType(String name) {
    final type = MediaFormats.classify(name);
    return switch (type) {
      MediaType.video => 'video',
      MediaType.audio => 'audio',
      MediaType.image => 'image',
      null => _documentExtensions.contains(_ext(name)) ? 'document' : 'other',
    };
  }

  String _classifyCategory({
    required String name,
    required String path,
    String? folderPath,
  }) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.contains('/download') || lowerPath.contains('downloads/')) {
      return VaultCategory.downloads.id;
    }

    final type = MediaFormats.classify(name);
    return switch (type) {
      MediaType.video => VaultCategory.videos.id,
      MediaType.audio => VaultCategory.audio.id,
      MediaType.image => VaultCategory.images.id,
      null => _documentExtensions.contains(_ext(name))
          ? VaultCategory.documents.id
          : VaultCategory.documents.id,
    };
  }

  String _ext(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  String _safeName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
