# DS Video Player — SQLite Schema (current: v2)

DB file: `ds_video_player.db` · Engine: `sqflite` · `PRAGMA foreign_keys = ON`
Migrations are versioned in `core/database/app_database.dart`. v1 + the v2
delta (`media_index` for incremental scanning) below.

```sql
-- Cached metadata for every discovered media file (video/audio/image).
CREATE TABLE media_items (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  uri           TEXT    NOT NULL UNIQUE,        -- content:// or file path
  title         TEXT    NOT NULL,
  type          TEXT    NOT NULL,               -- 'video' | 'audio' | 'image'
  folder_path   TEXT    NOT NULL,
  size_bytes    INTEGER NOT NULL DEFAULT 0,
  duration_ms   INTEGER NOT NULL DEFAULT 0,
  width         INTEGER,
  height        INTEGER,
  mime_type     TEXT,
  date_added    INTEGER NOT NULL,               -- epoch ms
  date_modified INTEGER NOT NULL,
  thumb_path    TEXT,
  is_hidden     INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_media_type    ON media_items(type);
CREATE INDEX idx_media_folder  ON media_items(folder_path);
CREATE INDEX idx_media_added   ON media_items(date_added);

-- Resume / continue-watching. position_ms = last playback position.
CREATE TABLE playback_history (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  media_uri     TEXT    NOT NULL,
  position_ms   INTEGER NOT NULL DEFAULT 0,
  duration_ms   INTEGER NOT NULL DEFAULT 0,
  played_at     INTEGER NOT NULL,               -- epoch ms (recently played order)
  play_count    INTEGER NOT NULL DEFAULT 1,
  completed     INTEGER NOT NULL DEFAULT 0,
  UNIQUE(media_uri)
);
CREATE INDEX idx_history_played_at ON playback_history(played_at);

CREATE TABLE favorites (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  media_uri  TEXT NOT NULL UNIQUE,
  added_at   INTEGER NOT NULL
);

CREATE TABLE playlists (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE playlist_items (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  playlist_id INTEGER NOT NULL,
  media_uri   TEXT    NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
);
CREATE INDEX idx_playlist_items_pl ON playlist_items(playlist_id, sort_order);

-- Private encrypted vault. original_uri kept to allow restore.
CREATE TABLE vault_items (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  vault_path    TEXT NOT NULL UNIQUE,           -- encrypted blob path in app-private dir
  original_name TEXT NOT NULL,
  original_uri  TEXT,
  type          TEXT NOT NULL,                  -- 'video' | 'audio' | 'image'
  size_bytes    INTEGER NOT NULL DEFAULT 0,
  added_at      INTEGER NOT NULL
);

-- Per-folder flags (hidden / pinned / no-media-scan equivalent).
CREATE TABLE folder_settings (
  folder_path TEXT PRIMARY KEY,
  is_hidden   INTEGER NOT NULL DEFAULT 0,
  is_pinned   INTEGER NOT NULL DEFAULT 0
);

-- Saved + custom equalizer presets. bands JSON: [gain_db,...] 10 bands.
CREATE TABLE equalizer_presets (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL UNIQUE,
  bands      TEXT NOT NULL,
  bass_boost INTEGER NOT NULL DEFAULT 0,
  loudness   INTEGER NOT NULL DEFAULT 0,
  is_custom  INTEGER NOT NULL DEFAULT 1
);

-- Lightweight key/value usage signals for the on-device recommender.
CREATE TABLE usage_events (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  media_uri  TEXT NOT NULL,
  event_type TEXT NOT NULL,                     -- 'play','complete','skip','favorite'
  weight     REAL NOT NULL DEFAULT 1.0,
  created_at INTEGER NOT NULL
);
CREATE INDEX idx_usage_uri ON usage_events(media_uri);
```

## v2 delta — incremental library index

```sql
-- One row per indexed media file. Uniqueness by path. Subsequent scans
-- compare (modified_at, size) against the device snapshot to decide
-- insert / update / skip / remove. indexed_at is when WE added the row
-- (powers "Recently Added"); modified_at is the file's mtime.
CREATE TABLE media_index (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  path           TEXT    NOT NULL UNIQUE,
  filename       TEXT    NOT NULL,
  modified_at    INTEGER NOT NULL,        -- file mtime, epoch ms
  size           INTEGER NOT NULL,
  duration_ms    INTEGER NOT NULL DEFAULT 0,
  media_type     TEXT    NOT NULL,        -- 'video' | 'audio' | 'image'
  thumbnail_path TEXT,
  indexed_at     INTEGER NOT NULL         -- when added to local index, epoch ms
);
CREATE INDEX idx_media_index_type       ON media_index(media_type);
CREATE INDEX idx_media_index_modified   ON media_index(modified_at);
CREATE INDEX idx_media_index_indexed_at ON media_index(indexed_at);
```

`media_index` is independent of `media_items` (v1). v1 holds the
presentation-layer cache used by the existing Video / Audio tabs; v2 holds
the canonical incremental index used by `LibraryScanService`. A later
branch will collapse the two once the new scanner has burned in.

**Settings & secrets are *not* in SQLite.** User preferences live in `shared_preferences`; PIN hash, vault key and premium token live in `flutter_secure_storage` (Android Keystore-backed).

**Recommender (on-device, no network):** score per item = `Σ usage_events.weight · recencyDecay(created_at)` + folder affinity + completion ratio. Pure SQL aggregation → ranked "Suggested for you" row. Duplicate finder = group by `size_bytes` then perceptual/quick-hash compare.
