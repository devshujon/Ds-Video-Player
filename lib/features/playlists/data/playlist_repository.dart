import '../../../../core/database/app_database.dart';
import '../domain/entities/playlist.dart';

/// CRUD + ordering for playlists, backed by the `playlists` /
/// `playlist_items` tables (schema v1). `playlist_items` has an
/// `ON DELETE CASCADE` FK, and `PRAGMA foreign_keys` is on, so deleting a
/// playlist drops its items automatically.
abstract interface class PlaylistRepository {
  Future<List<Playlist>> getAll();
  Future<Playlist> create(String name);
  Future<void> rename(int id, String name);
  Future<void> delete(int id);

  /// Ordered media URIs in a playlist.
  Future<List<String>> itemUris(int playlistId);

  /// Appends [uris], skipping any already present. Order preserved.
  Future<void> addItems(int playlistId, List<String> uris);

  Future<void> removeItem(int playlistId, String uri);

  /// Rewrites `sort_order` to match [orderedUris] exactly.
  Future<void> reorder(int playlistId, List<String> orderedUris);
}

class PlaylistRepositoryImpl implements PlaylistRepository {
  PlaylistRepositoryImpl(this._db);
  final AppDatabase _db;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<List<Playlist>> getAll() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT p.id, p.name, p.created_at, p.updated_at,
        (SELECT COUNT(*) FROM playlist_items pi
           WHERE pi.playlist_id = p.id) AS cnt
      FROM playlists p
      ORDER BY p.updated_at DESC
    ''');
    return rows
        .map((r) => Playlist(
              id: r['id'] as int,
              name: r['name'] as String,
              itemCount: (r['cnt'] as int?) ?? 0,
              createdAt: r['created_at'] as int,
              updatedAt: r['updated_at'] as int,
            ))
        .toList(growable: false);
  }

  @override
  Future<Playlist> create(String name) async {
    final db = await _db.database;
    final now = _now;
    final id = await db.insert('playlists', {
      'name': name,
      'created_at': now,
      'updated_at': now,
    });
    return Playlist(
      id: id,
      name: name,
      itemCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> rename(int id, String name) async {
    final db = await _db.database;
    await db.update(
      'playlists',
      {'name': name, 'updated_at': _now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<String>> itemUris(int playlistId) async {
    final db = await _db.database;
    final rows = await db.query(
      'playlist_items',
      columns: ['media_uri'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'sort_order ASC',
    );
    return rows.map((r) => r['media_uri'] as String).toList(growable: false);
  }

  @override
  Future<void> addItems(int playlistId, List<String> uris) async {
    if (uris.isEmpty) return;
    final db = await _db.database;
    await db.transaction((txn) async {
      final existing = (await txn.query(
        'playlist_items',
        columns: ['media_uri'],
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      ))
          .map((r) => r['media_uri'] as String)
          .toSet();

      final maxRow = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) AS m '
        'FROM playlist_items WHERE playlist_id = ?',
        [playlistId],
      );
      var order = (maxRow.first['m'] as int) + 1;

      final batch = txn.batch();
      for (final uri in uris) {
        if (existing.contains(uri)) continue;
        existing.add(uri); // guard against dupes within `uris` itself
        batch.insert('playlist_items', {
          'playlist_id': playlistId,
          'media_uri': uri,
          'sort_order': order++,
        });
      }
      await batch.commit(noResult: true);
      await txn.update(
        'playlists',
        {'updated_at': _now},
        where: 'id = ?',
        whereArgs: [playlistId],
      );
    });
  }

  @override
  Future<void> removeItem(int playlistId, String uri) async {
    final db = await _db.database;
    await db.delete(
      'playlist_items',
      where: 'playlist_id = ? AND media_uri = ?',
      whereArgs: [playlistId, uri],
    );
    await db.update(
      'playlists',
      {'updated_at': _now},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  @override
  Future<void> reorder(int playlistId, List<String> orderedUris) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedUris.length; i++) {
        await txn.update(
          'playlist_items',
          {'sort_order': i},
          where: 'playlist_id = ? AND media_uri = ?',
          whereArgs: [playlistId, orderedUris[i]],
        );
      }
      await txn.update(
        'playlists',
        {'updated_at': _now},
        where: 'id = ?',
        whereArgs: [playlistId],
      );
    });
  }
}
