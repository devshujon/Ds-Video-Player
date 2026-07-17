import 'dart:io';
import 'dart:typed_data';

import 'package:ds_video_player/features/duplicates/data/duplicate_finder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dupfinder');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<FileRef> write(String name, List<int> bytes) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsBytes(bytes);
    return FileRef(path: f.path, size: bytes.length);
  }

  List<int> pattern(int len, int seed) =>
      Uint8List.fromList(List.generate(len, (i) => (i + seed) & 0xFF));

  group('DuplicateFinder', () {
    test('detects two identical files', () async {
      const finder = DuplicateFinder(sampleBytes: 64);
      final content = pattern(200, 1);
      final a = await write('a.mp4', content);
      final b = await write('b.mp4', content);

      final groups = await finder.find([a, b]);

      expect(groups, hasLength(1));
      expect(groups.first.paths.toSet(), {a.path, b.path});
      expect(groups.first.sizeBytes, 200);
    });

    test('same size but different content is NOT a duplicate', () async {
      const finder = DuplicateFinder(sampleBytes: 64);
      final a = await write('a.mp4', pattern(200, 1));
      final b = await write('b.mp4', pattern(200, 99)); // same length

      final groups = await finder.find([a, b]);

      expect(groups, isEmpty);
    });

    test('unique-size files are skipped without hashing', () async {
      const finder = DuplicateFinder(sampleBytes: 64);
      final a = await write('a.mp4', pattern(100, 1));
      final b = await write('b.mp4', pattern(200, 1));
      final c = await write('c.mp4', pattern(300, 1));

      expect(await finder.find([a, b, c]), isEmpty);
    });

    test('groups three identical copies into one group', () async {
      const finder = DuplicateFinder(sampleBytes: 64);
      final content = pattern(500, 7);
      final a = await write('a.mp4', content);
      final b = await write('b.mp4', content);
      final c = await write('c.mp4', content);

      final groups = await finder.find([a, b, c]);

      expect(groups, hasLength(1));
      expect(groups.first.paths, hasLength(3));
      // Reclaimable = keep one, drop two.
      expect(groups.first.reclaimableBytes, 500 * 2);
    });

    test('separates two distinct duplicate sets at the same size', () async {
      const finder = DuplicateFinder(sampleBytes: 64);
      final x = pattern(256, 1);
      final y = pattern(256, 2); // same length, different content
      final x1 = await write('x1.mp4', x);
      final x2 = await write('x2.mp4', x);
      final y1 = await write('y1.mp4', y);
      final y2 = await write('y2.mp4', y);

      final groups = await finder.find([x1, x2, y1, y2]);

      expect(groups, hasLength(2));
      for (final g in groups) {
        expect(g.paths, hasLength(2));
      }
    });

    test('files larger than sampleBytes: prefix collision counts as dup',
        () async {
      // Two files share their first 64 bytes but differ afterwards.
      // With sampleBytes=64 the finder treats them as duplicates — the
      // documented fast-heuristic behaviour.
      const finder = DuplicateFinder(sampleBytes: 64);
      final head = pattern(64, 5);
      final a = await write('a.mp4', [...head, ...pattern(64, 10)]);
      final b = await write('b.mp4', [...head, ...pattern(64, 20)]);

      final groups = await finder.find([a, b]);
      expect(groups, hasLength(1));
    });

    test('reports progress from 0 toward 1', () async {
      const finder = DuplicateFinder(sampleBytes: 64);
      final content = pattern(120, 3);
      final a = await write('a.mp4', content);
      final b = await write('b.mp4', content);

      final samples = <double>[];
      await finder.find([a, b], onProgress: samples.add);

      expect(samples, isNotEmpty);
      expect(samples.last, 1.0);
    });

    test('empty input yields no groups', () async {
      const finder = DuplicateFinder();
      expect(await finder.find([]), isEmpty);
    });

    test('groups are ordered by reclaimable space, largest first', () async {
      const finder = DuplicateFinder(sampleBytes: 64);
      final small = pattern(100, 1);
      final big = pattern(900, 2);
      final s1 = await write('s1.mp4', small);
      final s2 = await write('s2.mp4', small);
      final b1 = await write('b1.mp4', big);
      final b2 = await write('b2.mp4', big);

      final groups = await finder.find([s1, s2, b1, b2]);

      expect(groups, hasLength(2));
      expect(groups.first.sizeBytes, 900); // biggest win first
      expect(groups.last.sizeBytes, 100);
    });
  });
}
