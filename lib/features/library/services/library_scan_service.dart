import 'dart:async';

import 'package:photo_manager/photo_manager.dart';

import '../models/media_index.dart';
import 'library_index_store.dart';

/// One observable update from an in-flight scan. Emitted on every
/// `yieldEveryNFiles` files processed plus a final event with `done = true`.
class ScanProgress {
  const ScanProgress({
    required this.filesScanned,
    required this.newItemsFound,
    required this.updatedItems,
    required this.removedItems,
    required this.done,
  });

  /// Files inspected so far. Total is unknown ahead of time when the source
  /// streams (so progress is *indeterminate* until [done]).
  final int filesScanned;
  final int newItemsFound;
  final int updatedItems;
  final int removedItems;
  final bool done;

  String summary() => '$newItemsFound added · '
      '$updatedItems updated · '
      '$removedItems removed';
}

/// A device-side media catalog. Implemented by [PhotoManagerMediaSource] in
/// production; replaced with an in-memory fake in tests.
abstract interface class MediaSource {
  Stream<MediaSourceEntry> stream();
}

class MediaSourceEntry {
  const MediaSourceEntry({
    required this.path,
    required this.filename,
    required this.modifiedAt,
    required this.size,
    required this.durationMs,
    required this.mediaType,
    this.thumbnailPath,
  });

  final String path;
  final String filename;
  final int modifiedAt;
  final int size;
  final int durationMs;
  final String mediaType;
  final String? thumbnailPath;
}

/// Incremental media library scanner.
///
/// First scan inserts every entry the [MediaSource] yields. Subsequent scans
/// compare `modifiedAt` + `size` against the stored snapshot and:
///
///   • **skip** unchanged files (no DB write at all),
///   • **upsert** files whose mtime or size differs,
///   • **insert** new files,
///   • **delete** index rows for paths the device no longer reports.
///
/// Persists in batches and yields to the event loop every
/// `yieldEveryNFiles` entries so the UI thread stays responsive even on
/// large libraries.
class LibraryScanService {
  LibraryScanService(this._source, this._store);

  final MediaSource _source;
  final LibraryIndexStore _store;

  Stream<ScanProgress> scan({
    int batchSize = 200,
    int yieldEveryNFiles = 100,
  }) async* {
    assert(batchSize > 0);
    assert(yieldEveryNFiles > 0);

    final indexed = await _store.snapshotByPath();
    final seenPaths = <String>{};
    final pending = <MediaIndex>[];

    var filesScanned = 0;
    var newCount = 0;
    var updatedCount = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    yield const ScanProgress(
      filesScanned: 0,
      newItemsFound: 0,
      updatedItems: 0,
      removedItems: 0,
      done: false,
    );

    await for (final entry in _source.stream()) {
      seenPaths.add(entry.path);
      final existing = indexed[entry.path];

      MediaIndex? toSave;
      if (existing == null) {
        toSave = MediaIndex(
          path: entry.path,
          filename: entry.filename,
          modifiedAt: entry.modifiedAt,
          size: entry.size,
          durationMs: entry.durationMs,
          mediaType: entry.mediaType,
          thumbnailPath: entry.thumbnailPath,
          indexedAt: now,
        );
        newCount++;
      } else if (existing.modifiedAt != entry.modifiedAt ||
          existing.size != entry.size) {
        toSave = existing.copyWith(
          filename: entry.filename,
          modifiedAt: entry.modifiedAt,
          size: entry.size,
          durationMs: entry.durationMs,
          mediaType: entry.mediaType,
          thumbnailPath: entry.thumbnailPath ?? existing.thumbnailPath,
        );
        updatedCount++;
      }
      // else: unchanged → no write, just bookkeeping in `seenPaths`.

      if (toSave != null) pending.add(toSave);
      filesScanned++;

      if (pending.length >= batchSize) {
        await _store.upsertBatch(pending);
        pending.clear();
      }

      if (filesScanned % yieldEveryNFiles == 0) {
        yield ScanProgress(
          filesScanned: filesScanned,
          newItemsFound: newCount,
          updatedItems: updatedCount,
          removedItems: 0,
          done: false,
        );
        // Cooperative yield: hands the event loop back to the UI thread.
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (pending.isNotEmpty) {
      await _store.upsertBatch(pending);
      pending.clear();
    }

    // Anything the device no longer reports has been deleted/moved.
    final removed = <String>[];
    for (final p in indexed.keys) {
      if (!seenPaths.contains(p)) removed.add(p);
    }
    if (removed.isNotEmpty) {
      await _store.removeByPaths(removed);
    }

    yield ScanProgress(
      filesScanned: filesScanned,
      newItemsFound: newCount,
      updatedItems: updatedCount,
      removedItems: removed.length,
      done: true,
    );
  }
}

/// Production [MediaSource]: pages the device MediaStore via `photo_manager`.
/// Yields lazily so the scanner can pipeline persistence with discovery.
class PhotoManagerMediaSource implements MediaSource {
  const PhotoManagerMediaSource();

  @override
  Stream<MediaSourceEntry> stream() async* {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!(ps.isAuth || ps.hasAccess)) return;

    const buckets = <(RequestType, String)>[
      (RequestType.video, 'video'),
      (RequestType.audio, 'audio'),
      (RequestType.image, 'image'),
    ];

    for (final (req, type) in buckets) {
      final paths = await PhotoManager.getAssetPathList(
        type: req,
        onlyAll: true,
      );
      if (paths.isEmpty) continue;
      final album = paths.first;
      final total = await album.assetCountAsync;

      const pageSize = 200;
      for (var page = 0; page * pageSize < total; page++) {
        final assets =
            await album.getAssetListPaged(page: page, size: pageSize);
        for (final a in assets) {
          final file = await a.file;
          if (file == null) continue;
          yield MediaSourceEntry(
            path: file.path,
            filename: file.path.split('/').last,
            modifiedAt: a.modifiedDateTime.millisecondsSinceEpoch,
            size: await file.length(),
            durationMs: a.duration * 1000,
            mediaType: type,
            thumbnailPath: null,
          );
        }
      }
    }
  }
}
