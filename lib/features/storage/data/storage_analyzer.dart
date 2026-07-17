/// A media file as seen by the storage analyzer.
class MediaFileInfo {
  const MediaFileInfo({
    required this.path,
    required this.type,
    required this.size,
  });

  final String path;

  /// `'video' | 'audio' | 'image'`.
  final String type;

  /// Size in bytes.
  final int size;
}

/// Outcome of a storage analysis pass.
class StorageReport {
  const StorageReport({
    required this.totalBytes,
    required this.bytesByType,
    required this.largest,
    required this.fileCount,
  });

  /// Total bytes across all analysed files.
  final int totalBytes;

  /// Bytes per media type (`'video'`, `'audio'`, `'image'`).
  final Map<String, int> bytesByType;

  /// Biggest files first, capped at the analyzer's `topCount`.
  final List<MediaFileInfo> largest;

  final int fileCount;

  bool get isEmpty => fileCount == 0;
}

/// Pure storage analysis. Buckets media by type, totals bytes, and surfaces
/// the largest files so the user can reclaim space deliberately.
class StorageAnalyzer {
  const StorageAnalyzer({this.topCount = 30});

  /// How many "largest files" to surface.
  final int topCount;

  StorageReport analyze(List<MediaFileInfo> files) {
    var total = 0;
    final byType = <String, int>{};
    for (final f in files) {
      final size = f.size < 0 ? 0 : f.size;
      total += size;
      byType.update(f.type, (v) => v + size, ifAbsent: () => size);
    }

    final sorted = [...files]..sort((a, b) => b.size.compareTo(a.size));

    return StorageReport(
      totalBytes: total,
      bytesByType: byType,
      largest: sorted.take(topCount).toList(growable: false),
      fileCount: files.length,
    );
  }
}
