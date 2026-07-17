import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/storage_analyzer.dart';

enum StorageCleanerStatus { idle, analyzing, done }

/// Route-scoped state for the storage cleaner screen.
class StorageCleanerProvider extends ChangeNotifier {
  StorageCleanerProvider(this._analyzer);
  final StorageAnalyzer _analyzer;

  // M1 — lifecycle guard: analysis/deletion can finish after route pop.
  bool _disposed = false;

  StorageCleanerStatus status = StorageCleanerStatus.idle;
  StorageReport? report;

  /// Paths marked for deletion (from the "largest files" list).
  final Set<String> selected = {};

  int get selectedCount => selected.length;

  int get reclaimableBytes {
    final r = report;
    if (r == null) return 0;
    var total = 0;
    for (final f in r.largest) {
      if (selected.contains(f.path)) total += f.size;
    }
    return total;
  }

  Future<void> analyze(List<MediaFileInfo> files) async {
    status = StorageCleanerStatus.analyzing;
    selected.clear();
    notifyListeners();

    // analyze is pure + fast; the await keeps the UI frame free.
    report = await Future<StorageReport>(() => _analyzer.analyze(files));
    status = StorageCleanerStatus.done;
    notifyListeners();
  }

  void toggle(String path) {
    if (!selected.remove(path)) selected.add(path);
    notifyListeners();
  }

  bool isSelected(String path) => selected.contains(path);

  /// Deletes the selected files, then adjusts the report in place — totals
  /// drop by exactly what was removed, undeletable files stay listed.
  /// Returns the number of files actually removed from disk.
  Future<int> deleteSelected() async {
    final r = report;
    if (r == null) return 0;

    var deletedCount = 0;
    var deletedBytes = 0;
    final survivors = <MediaFileInfo>[];
    final byTypeDelta = <String, int>{};

    for (final f in r.largest) {
      if (!selected.contains(f.path)) {
        survivors.add(f);
        continue;
      }
      try {
        final file = File(f.path);
        if (await file.exists()) {
          await file.delete();
          deletedCount++;
          deletedBytes += f.size;
          byTypeDelta.update(f.type, (v) => v + f.size,
              ifAbsent: () => f.size);
        } else {
          survivors.add(f); // already gone — drop quietly
        }
      } catch (_) {
        survivors.add(f); // undeletable — keep it listed
      }
    }

    final newByType = <String, int>{...r.bytesByType};
    byTypeDelta.forEach((type, bytes) {
      newByType[type] = ((newByType[type] ?? 0) - bytes).clamp(0, 1 << 62);
    });

    report = StorageReport(
      totalBytes: (r.totalBytes - deletedBytes).clamp(0, 1 << 62),
      bytesByType: newByType,
      largest: survivors,
      fileCount: (r.fileCount - deletedCount).clamp(0, 1 << 62),
    );
    selected.clear();
    notifyListeners();
    return deletedCount;
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
