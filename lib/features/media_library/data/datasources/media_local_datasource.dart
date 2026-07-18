import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/media_item.dart';
import '../models/media_item_model.dart';

/// SQLite cache: metadata, favorites, resume history, folder flags.
class MediaLocalDataSource {
  MediaLocalDataSource(this._appDb);
  final AppDatabase _appDb;

  Future<List<MediaItem>> queryHidden() async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
      SELECT mi.*,
        CASE WHEN f.media_uri IS NULL THEN 0 ELSE 1 END AS fav,
        COALESCE(h.position_ms, 0) AS resume_ms
      FROM media_items mi
      LEFT JOIN favorites f ON f.media_uri = mi.uri
      LEFT JOIN playback_history h ON h.media_uri = mi.uri
      WHERE mi.is_hidden = 1
      ORDER BY mi.date_added DESC
    ''');
    return rows
        .map((r) => MediaItemModel.fromRow(
              r,
              isFavorite: r['fav'] == 1,
              resumePositionMs: (r['resume_ms'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<void> upsertAll(List<MediaItem> items) async {
    final db = await _appDb.database;
    final batch = db.batch();
    for (final m in items) {
      batch.insert(
        'media_items',
        MediaItemModel.toRow(m),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<MediaItem>> queryByType(String type) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
      SELECT mi.*,
        CASE WHEN f.media_uri IS NULL THEN 0 ELSE 1 END AS fav,
        COALESCE(h.position_ms, 0) AS resume_ms
      FROM media_items mi
      LEFT JOIN favorites f ON f.media_uri = mi.uri
      LEFT JOIN playback_history h ON h.media_uri = mi.uri
      WHERE mi.type = ? AND mi.is_hidden = 0
      ORDER BY mi.date_added DESC
      ''',
      [type],
    );
    return rows
        .map((r) => MediaItemModel.fromRow(
              r,
              isFavorite: r['fav'] == 1,
              resumePositionMs: (r['resume_ms'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<List<Map<String, Object?>>> folderCounts() async {
    final db = await _appDb.database;
    return db.rawQuery('''
      SELECT mi.folder_path AS path, COUNT(*) AS cnt,
        COALESCE(fs.is_hidden, 0) AS hidden
      FROM media_items mi
      LEFT JOIN folder_settings fs ON fs.folder_path = mi.folder_path
      WHERE mi.type = 'video'
      GROUP BY mi.folder_path
      ORDER BY cnt DESC
    ''');
  }

  Future<List<MediaItem>> favorites() async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
      SELECT mi.*, 1 AS fav, COALESCE(h.position_ms,0) AS resume_ms
      FROM favorites f
      JOIN media_items mi ON mi.uri = f.media_uri
      LEFT JOIN playback_history h ON h.media_uri = mi.uri
      ORDER BY f.added_at DESC
    ''');
    return rows
        .map((r) => MediaItemModel.fromRow(r,
            isFavorite: true,
            resumePositionMs: (r['resume_ms'] as int?) ?? 0))
        .toList();
  }

  Future<List<MediaItem>> recentlyPlayed() async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
      SELECT mi.*, h.position_ms AS resume_ms,
        CASE WHEN f.media_uri IS NULL THEN 0 ELSE 1 END AS fav
      FROM playback_history h
      JOIN media_items mi ON mi.uri = h.media_uri
      LEFT JOIN favorites f ON f.media_uri = mi.uri
      ORDER BY h.played_at DESC LIMIT 50
    ''');
    return rows
        .map((r) => MediaItemModel.fromRow(r,
            isFavorite: r['fav'] == 1,
            resumePositionMs: (r['resume_ms'] as int?) ?? 0))
        .toList();
  }

  Future<List<MediaItem>> search(String q) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'media_items',
      where: 'title LIKE ? AND is_hidden = 0',
      whereArgs: ['%$q%'],
      orderBy: 'date_added DESC',
      limit: 200,
    );
    return rows.map((r) => MediaItemModel.fromRow(r)).toList();
  }

  Future<bool> toggleFavorite(String uri) async {
    final db = await _appDb.database;
    final existing = await db.query('favorites',
        where: 'media_uri = ?', whereArgs: [uri], limit: 1);
    if (existing.isEmpty) {
      await db.insert('favorites', {
        'media_uri': uri,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    }
    await db.delete('favorites', where: 'media_uri = ?', whereArgs: [uri]);
    return false;
  }

  Future<void> saveResume({
    required String uri,
    required int positionMs,
    required int durationMs,
  }) async {
    final db = await _appDb.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final completed = durationMs > 0 && positionMs >= durationMs * 0.95 ? 1 : 0;
    await db.insert(
      'playback_history',
      {
        'media_uri': uri,
        'position_ms': completed == 1 ? 0 : positionMs,
        'duration_ms': durationMs,
        'played_at': now,
        'play_count': 1,
        'completed': completed,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteByUri(String uri) async {
    final db = await _appDb.database;
    await db.delete('favorites', where: 'media_uri = ?', whereArgs: [uri]);
    await db.delete('playback_history', where: 'media_uri = ?', whereArgs: [uri]);
    await db.delete('usage_events', where: 'media_uri = ?', whereArgs: [uri]);
    await db.delete('media_items', where: 'uri = ?', whereArgs: [uri]);
  }

  Future<void> setFolderHidden(String path, bool hidden) async {
    final db = await _appDb.database;
    await db.insert(
      'folder_settings',
      {'folder_path': path, 'is_hidden': hidden ? 1 : 0, 'is_pinned': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.update('media_items', {'is_hidden': hidden ? 1 : 0},
        where: 'folder_path = ?', whereArgs: [path]);
  }
}
