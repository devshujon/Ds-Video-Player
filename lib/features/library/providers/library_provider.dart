import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/media_index.dart';
import '../services/library_index_store.dart';
import '../services/library_scan_service.dart';

/// UI state for the incremental library scanner.
///
/// Subscribes to [LibraryScanService.scan] and mirrors progress into
/// observable fields. `scanProgress` is **indeterminate** (`-1.0`) while a
/// streaming scan is in flight, since the total file count isn't known
/// up-front; it resolves to `1.0` on completion.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._service, this._store);

  final LibraryScanService _service;
  final LibraryIndexStore _store;

  bool isScanning = false;

  /// `-1.0` = indeterminate (UI should render an indeterminate bar),
  /// `0.0`–`1.0` = fractional, `1.0` = done.
  double scanProgress = 0.0;

  int filesScanned = 0;
  int newItemsFound = 0;
  int updatedItems = 0;
  int removedItems = 0;

  /// Set when the latest scan completes; cleared at the next scan start.
  String? lastSummary;

  List<MediaIndex> recentlyAdded = const [];

  StreamSubscription<ScanProgress>? _sub;

  /// Loads the "Recently Added" row from the persisted index. Safe to call
  /// at any time; cheap (`LIMIT 20`).
  Future<void> loadRecent({int limit = 20}) async {
    recentlyAdded = await _store.recentlyAdded(limit: limit);
    notifyListeners();
  }

  /// Kicks off a scan. Returns when the scan completes (or is cancelled by
  /// a subsequent call). Calling while a scan is already in flight is a
  /// no-op.
  Future<void> scan() async {
    if (isScanning) return;

    isScanning = true;
    scanProgress = -1.0;
    filesScanned = 0;
    newItemsFound = 0;
    updatedItems = 0;
    removedItems = 0;
    lastSummary = null;
    notifyListeners();

    await _sub?.cancel();
    final completer = Completer<void>();

    _sub = _service.scan().listen(
      (p) {
        filesScanned = p.filesScanned;
        newItemsFound = p.newItemsFound;
        updatedItems = p.updatedItems;
        removedItems = p.removedItems;
        scanProgress = p.done ? 1.0 : -1.0;
        if (p.done) {
          isScanning = false;
          lastSummary = p.summary();
        }
        notifyListeners();
      },
      onError: (Object e, StackTrace _) {
        isScanning = false;
        scanProgress = 0.0;
        lastSummary = 'Scan failed: $e';
        notifyListeners();
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () async {
        // Refresh "Recently Added" once the persist tail has flushed.
        await loadRecent();
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
