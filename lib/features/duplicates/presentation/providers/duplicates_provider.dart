import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/duplicate_finder.dart';

enum DuplicatesStatus { idle, scanning, done }

/// Route-scoped state for the duplicate-finder screen.
///
/// After a scan, every group has all-but-the-first copy pre-selected for
/// deletion — the common intent is "keep one, drop the rest" — but the
/// selection is fully editable before the user commits.
class DuplicatesProvider extends ChangeNotifier {
  DuplicatesProvider(this._finder);
  final DuplicateFinder _finder;

  // M1 — lifecycle guard: a long scan can finish after the route is popped.
  bool _disposed = false;

  DuplicatesStatus status = DuplicatesStatus.idle;
  double progress = 0.0;
  List<DuplicateGroup> groups = const [];

  /// Paths currently marked for deletion.
  final Set<String> selected = {};

  int get selectedCount => selected.length;

  int get reclaimableBytes {
    var total = 0;
    for (final g in groups) {
      for (final path in g.paths) {
        if (selected.contains(path)) total += g.sizeBytes;
      }
    }
    return total;
  }

  Future<void> scan(List<FileRef> files) async {
    status = DuplicatesStatus.scanning;
    progress = 0;
    groups = const [];
    selected.clear();
    notifyListeners();

    final found = await _finder.find(
      files,
      onProgress: (p) {
        progress = p;
        notifyListeners();
      },
    );

    groups = found;
    // Pre-select extras (keep the first copy of each group).
    selected
      ..clear()
      ..addAll(found.expand((g) => g.paths.skip(1)));
    status = DuplicatesStatus.done;
    notifyListeners();
  }

  void toggle(String path) {
    if (!selected.remove(path)) selected.add(path);
    notifyListeners();
  }

  bool isSelected(String path) => selected.contains(path);

  /// Deletes every selected file, then prunes the now-resolved groups.
  /// Returns the number of files actually removed from disk.
  Future<int> deleteSelected() async {
    var deleted = 0;
    for (final path in selected.toList(growable: false)) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
          deleted++;
        }
      } catch (_) {
        // Leave undeletable files in place; they stay listed.
      }
    }

    groups = groups
        .map((g) => DuplicateGroup(
              sizeBytes: g.sizeBytes,
              paths: g.paths
                  .where((p) => !selected.contains(p))
                  .toList(growable: false),
            ))
        .where((g) => g.paths.length > 1)
        .toList(growable: false);
    selected
      ..clear()
      ..addAll(groups.expand((g) => g.paths.skip(1)));
    notifyListeners();
    return deleted;
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
