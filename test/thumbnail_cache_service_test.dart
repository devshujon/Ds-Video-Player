import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ds_video_player/core/constants/app_constants.dart';
import 'package:ds_video_player/core/services/thumbnail_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThumbnailCacheService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('thumb_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('save and pathFor round-trip', () async {
      final cache = ThumbnailCacheService(overrideDir: tempDir);
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]);
      final path = await cache.save('file:///test/video.mp4', bytes);
      expect(path, isNotNull);
      final hit = await cache.pathFor('file:///test/video.mp4');
      expect(hit, path);
    });

    test('memory LRU evicts beyond max entries', () async {
      final cache = ThumbnailCacheService(overrideDir: tempDir);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final max = AppConstants.thumbnailMaxMemoryEntries;
      for (var i = 0; i < max + 5; i++) {
        await cache.save('file:///v$i.mp4', bytes);
      }
      expect(cache.pathInMemory('file:///v0.mp4'), isNull);
      expect(cache.pathInMemory('file:///v${max + 4}.mp4'), isNotNull);
    });
  });
}
