import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../models/media_index.dart';

/// Persistence boundary for [MediaIndex]. Abstracted so the scanner can be
/// unit-tested against an in-memory implementation without sqflite.
abstract interface class LibraryIndexStore {
  /// Loads every indexed record, keyed by [MediaIndex.path].
  ///
  /// The scanner uses this snapshot to detect deltas in a single pass.
  /// For very large libraries (≫100k items) this could be replaced with a
  /// streaming compare; at present sub-100k is the realistic target and
  /// fits comfortably in memory.
  Future<Map<String, MediaIndex>> snapshotByPath();

  /// Upsert by `path`. Conflicting rows are replaced.
  Future<void> upsertBatch(List<MediaIndex> items);

  /// Bulk delete by path. Chunks internally to stay under the SQLite host
  /// parameter limit (~999).
  Future<void> removeByPaths(List<String> paths);

  /// Most recently indexed first, capped at [limit]. Powers the
  /// "Recently Added" row on the library screen.
  Future<List<MediaIndex>> recentlyAdded({int limit = 20});

  Future<int> count();
}

class SqliteLibraryIndexStore implements LibraryIndexStore {
  SqliteLibraryIndexStore(this._appDb);
  final AppDatabase _appDb;

  static const String _table = 'media_index';

  @override
  Future<Map<String, MediaIndex>> snapshotByPath() async {
    final db = await _appDb.database;
    final rows = await db.query(_table);
    final map = <String, MediaIndex>{};
    for (final r in rows) {
      final m = MediaIndex.fromRow(r);
      map[m.path] = m;
    }
    return map;
  }

  @override
  Future<void> upsertBatch(List<MediaIndex> items) async {
    if (items.isEmpty) return;
    final db = await _appDb.database;
    final batch = db.batch();
    for (final m in items) {
      batch.insert(
        _table,
        m.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> removeByPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    final db = await _appDb.database;
    const chunkSize = 500;
    for (var i = 0; i < paths.length; i += chunkSize) {
      final end = (i + chunkSize) > paths.length ? paths.length : i + chunkSize;
      final chunk = paths.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      await db.delete(
        _table,
        where: 'path IN ($placeholders)',
        whereArgs: chunk,
      );
    }
  }

  @override
  Future<List<MediaIndex>> recentlyAdded({int limit = 20}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      _table,
      orderBy: 'indexed_at DESC',
      limit: limit,
    );
    return rows.map(MediaIndex.fromRow).toList();
  }

  @override
  Future<int> count() async {
    final db = await _appDb.database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return (r.first['c'] as int?) ?? 0;
  }
}
