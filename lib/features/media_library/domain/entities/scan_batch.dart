import '../entities/media_item.dart';

/// Progressive scan emission. UI can render [items] immediately while
/// [done] is false — no need to wait for the full library walk.
class ScanBatch {
  const ScanBatch({
    required this.items,
    required this.scannedCount,
    required this.done,
  });

  final List<MediaItem> items;
  final int scannedCount;
  final bool done;
}
