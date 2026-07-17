import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';
import '../logging/app_log.dart';

/// Single owner of the SQLite connection. Schema and migrations live here.
/// See docs/02_DATABASE_SCHEMA.md for the full schema rationale.
class AppDatabase {
  /// [overridePath] is a test seam — pass `inMemoryDatabasePath` (with the
  /// ffi factory installed) to run against a throwaway in-memory database.
  /// Production leaves it null and the DB lands in the app documents dir.
  AppDatabase({String? overridePath}) : _overridePath = overridePath;

  final String? _overridePath;
  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<String> _resolvePath() async {
    if (_overridePath != null) return _overridePath;
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, AppConstants.databaseName);
  }

  Future<Database> _open() async {
    final path = await _resolvePath();
    try {
      return await _openAt(path);
    } on DatabaseException catch (e) {
      if (_isCorruption(e)) {
        AppLog.warn('Database corrupt — recreating', e);
        await _recreate(path);
        return _openAt(path);
      }
      rethrow;
    } catch (e, st) {
      AppLog.error('Database open failed', e, st);
      rethrow;
    }
  }

  bool _isCorruption(DatabaseException e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('corrupt') ||
        msg.contains('malformed') ||
        msg.contains('not a database');
  }

  Future<void> _recreate(String path) async {
    try {
      await close();
      await deleteDatabase(path);
    } catch (e, st) {
      AppLog.warn('Database recreate failed', e, st);
    }
  }

  Future<Database> _openAt(String path) {
    return openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final stmt in _schemaV1) {
      batch.execute(stmt);
    }
    for (final stmt in _migrationV2) {
      batch.execute(stmt);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int from, int to) async {
    // Forward-only migrations. Each future version appends its own block.
    if (from < 2) {
      final batch = db.batch();
      for (final stmt in _migrationV2) {
        batch.execute(stmt);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static const List<String> _schemaV1 = [
    '''CREATE TABLE media_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uri TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      type TEXT NOT NULL,
      folder_path TEXT NOT NULL,
      size_bytes INTEGER NOT NULL DEFAULT 0,
      duration_ms INTEGER NOT NULL DEFAULT 0,
      width INTEGER,
      height INTEGER,
      mime_type TEXT,
      date_added INTEGER NOT NULL,
      date_modified INTEGER NOT NULL,
      thumb_path TEXT,
      is_hidden INTEGER NOT NULL DEFAULT 0
    )''',
    'CREATE INDEX idx_media_type ON media_items(type)',
    'CREATE INDEX idx_media_folder ON media_items(folder_path)',
    'CREATE INDEX idx_media_added ON media_items(date_added)',
    '''CREATE TABLE playback_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      media_uri TEXT NOT NULL UNIQUE,
      position_ms INTEGER NOT NULL DEFAULT 0,
      duration_ms INTEGER NOT NULL DEFAULT 0,
      played_at INTEGER NOT NULL,
      play_count INTEGER NOT NULL DEFAULT 1,
      completed INTEGER NOT NULL DEFAULT 0
    )''',
    'CREATE INDEX idx_history_played_at ON playback_history(played_at)',
    '''CREATE TABLE favorites(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      media_uri TEXT NOT NULL UNIQUE,
      added_at INTEGER NOT NULL
    )''',
    '''CREATE TABLE playlists(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''',
    '''CREATE TABLE playlist_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      playlist_id INTEGER NOT NULL,
      media_uri TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
    )''',
    'CREATE INDEX idx_playlist_items_pl ON playlist_items(playlist_id, sort_order)',
    '''CREATE TABLE vault_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      vault_path TEXT NOT NULL UNIQUE,
      original_name TEXT NOT NULL,
      original_uri TEXT,
      type TEXT NOT NULL,
      size_bytes INTEGER NOT NULL DEFAULT 0,
      added_at INTEGER NOT NULL
    )''',
    '''CREATE TABLE folder_settings(
      folder_path TEXT PRIMARY KEY,
      is_hidden INTEGER NOT NULL DEFAULT 0,
      is_pinned INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE equalizer_presets(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      bands TEXT NOT NULL,
      bass_boost INTEGER NOT NULL DEFAULT 0,
      loudness INTEGER NOT NULL DEFAULT 0,
      is_custom INTEGER NOT NULL DEFAULT 1
    )''',
    '''CREATE TABLE usage_events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      media_uri TEXT NOT NULL,
      event_type TEXT NOT NULL,
      weight REAL NOT NULL DEFAULT 1.0,
      created_at INTEGER NOT NULL
    )''',
    'CREATE INDEX idx_usage_uri ON usage_events(media_uri)',
  ];

  /// v2: incremental-scan index (feature/library-incremental-scan).
  static const List<String> _migrationV2 = [
    '''CREATE TABLE media_index(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      path TEXT NOT NULL UNIQUE,
      filename TEXT NOT NULL,
      modified_at INTEGER NOT NULL,
      size INTEGER NOT NULL,
      duration_ms INTEGER NOT NULL DEFAULT 0,
      media_type TEXT NOT NULL,
      thumbnail_path TEXT,
      indexed_at INTEGER NOT NULL
    )''',
    'CREATE INDEX idx_media_index_type ON media_index(media_type)',
    'CREATE INDEX idx_media_index_modified ON media_index(modified_at)',
    'CREATE INDEX idx_media_index_indexed_at ON media_index(indexed_at)',
  ];
}
