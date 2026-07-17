import 'package:ds_video_player/features/storage/data/storage_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

MediaFileInfo f(String path, int size, [String type = 'video']) =>
    MediaFileInfo(path: path, type: type, size: size);

void main() {
  group('StorageAnalyzer.analyze', () {
    test('empty input yields a zeroed report', () {
      final r = const StorageAnalyzer().analyze([]);
      expect(r.isEmpty, isTrue);
      expect(r.totalBytes, 0);
      expect(r.fileCount, 0);
      expect(r.largest, isEmpty);
    });

    test('sums total bytes and counts files', () {
      final r = const StorageAnalyzer().analyze([
        f('/a', 100),
        f('/b', 250),
        f('/c', 50),
      ]);
      expect(r.totalBytes, 400);
      expect(r.fileCount, 3);
    });

    test('buckets bytes by media type', () {
      final r = const StorageAnalyzer().analyze([
        f('/v1', 1000, 'video'),
        f('/v2', 500, 'video'),
        f('/a1', 300, 'audio'),
      ]);
      expect(r.bytesByType['video'], 1500);
      expect(r.bytesByType['audio'], 300);
    });

    test('largest list is sorted by size, descending', () {
      final r = const StorageAnalyzer().analyze([
        f('/small', 10),
        f('/big', 9000),
        f('/mid', 500),
      ]);
      expect(r.largest.map((e) => e.path), ['/big', '/mid', '/small']);
    });

    test('largest list is capped at topCount', () {
      final files =
          List.generate(50, (i) => f('/m$i', (i + 1) * 100));
      final r = const StorageAnalyzer(topCount: 10).analyze(files);
      expect(r.largest, hasLength(10));
      // Biggest is /m49 (5000 bytes).
      expect(r.largest.first.path, '/m49');
    });

    test('negative sizes are clamped to zero in totals', () {
      final r = const StorageAnalyzer().analyze([
        f('/ok', 200),
        f('/bad', -50),
      ]);
      expect(r.totalBytes, 200);
      expect(r.bytesByType['video'], 200);
    });
  });
}
