import 'dart:io';

import 'package:crypto/crypto.dart';

/// A file to consider for duplicate detection.
class FileRef {
  const FileRef({required this.path, required this.size});
  final String path;
  final int size;
}

/// Two or more files with identical size and content fingerprint.
class DuplicateGroup {
  const DuplicateGroup({required this.sizeBytes, required this.paths});

  final int sizeBytes;
  final List<String> paths; // length >= 2

  /// Bytes reclaimable by keeping one copy and deleting the rest.
  int get reclaimableBytes => sizeBytes * (paths.length - 1);
}

/// Finds duplicate media files in two cheap passes:
///
///   1. **Bucket by exact size.** Files with a unique size cannot have a
///      duplicate — discarded immediately, zero I/O.
///   2. **Fingerprint each same-size file** with a SHA-256 of its first
///      [sampleBytes] bytes. Same size + same prefix hash ⇒ duplicate.
///
/// Hashing only a prefix keeps multi-GB videos fast; for media files a
/// size + first-1-MiB collision between genuinely different files is
/// astronomically unlikely. When a file is smaller than [sampleBytes] the
/// prefix hash is in fact the full-content hash, so small files are exact.
class DuplicateFinder {
  const DuplicateFinder({this.sampleBytes = 1024 * 1024});

  /// Number of leading bytes hashed as the content fingerprint.
  final int sampleBytes;

  Future<List<DuplicateGroup>> find(
    List<FileRef> files, {
    void Function(double fraction)? onProgress,
  }) async {
    // Pass 1 — bucket by size, drop unique sizes.
    final bySize = <int, List<FileRef>>{};
    for (final f in files) {
      if (f.size <= 0) continue;
      bySize.putIfAbsent(f.size, () => []).add(f);
    }
    final candidates =
        bySize.values.where((b) => b.length > 1).toList(growable: false);

    final totalToHash =
        candidates.fold<int>(0, (sum, b) => sum + b.length);
    var hashed = 0;

    // Pass 2 — fingerprint within each size bucket.
    final groups = <DuplicateGroup>[];
    for (final bucket in candidates) {
      final byHash = <String, List<FileRef>>{};
      for (final f in bucket) {
        final fingerprint = await _prefixHash(f.path);
        if (fingerprint != null) {
          byHash.putIfAbsent(fingerprint, () => []).add(f);
        }
        hashed++;
        onProgress?.call(totalToHash == 0 ? 1.0 : hashed / totalToHash);
      }
      for (final matched in byHash.values) {
        if (matched.length > 1) {
          groups.add(DuplicateGroup(
            sizeBytes: matched.first.size,
            paths: matched.map((e) => e.path).toList(growable: false),
          ));
        }
      }
    }

    // Biggest space win first.
    groups.sort(
      (a, b) => b.reclaimableBytes.compareTo(a.reclaimableBytes),
    );
    return groups;
  }

  Future<String?> _prefixHash(String path) async {
    RandomAccessFile? raf;
    try {
      raf = await File(path).open();
      final length = await raf.length();
      final toRead = length < sampleBytes ? length : sampleBytes;
      final bytes = await raf.read(toRead);
      return sha256.convert(bytes).toString();
    } catch (_) {
      // Unreadable file (permissions, deleted mid-scan) — skip it.
      return null;
    } finally {
      await raf?.close();
    }
  }
}
