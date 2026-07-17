import 'package:ds_video_player/features/library/models/media_index.dart';
import 'package:ds_video_player/features/library/services/library_index_store.dart';
import 'package:ds_video_player/features/library/services/library_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory store used in lieu of sqflite. Tracks call counts so tests
/// can assert that *unchanged* scans perform no writes.
class _InMemoryStore implements LibraryIndexStore {
  final Map<String, MediaIndex> data = {};
  int upsertCalls = 0;
  int removeCalls = 0;
  int upsertedRows = 0;
  int removedRows = 0;

  @override
  Future<int> count() async => data.length;

  @override
  Future<List<MediaIndex>> recentlyAdded({int limit = 20}) async {
    final list = data.values.toList()
      ..sort((a, b) => b.indexedAt.compareTo(a.indexedAt));
    return list.take(limit).toList();
  }

  @override
  Future<void> removeByPaths(List<String> paths) async {
    removeCalls++;
    removedRows += paths.length;
    for (final p in paths) {
      data.remove(p);
    }
  }

  @override
  Future<Map<String, MediaIndex>> snapshotByPath() async => Map.of(data);

  @override
  Future<void> upsertBatch(List<MediaIndex> items) async {
    upsertCalls++;
    upsertedRows += items.length;
    for (final m in items) {
      data[m.path] = m;
    }
  }
}

class _ListSource implements MediaSource {
  _ListSource(this.entries);
  final List<MediaSourceEntry> entries;
  @override
  Stream<MediaSourceEntry> stream() => Stream.fromIterable(entries);
}

MediaSourceEntry _entry(
  String name, {
  int mtime = 1000,
  int size = 100,
  String type = 'video',
}) {
  return MediaSourceEntry(
    path: '/test/$name',
    filename: name,
    modifiedAt: mtime,
    size: size,
    durationMs: 0,
    mediaType: type,
  );
}

MediaIndex _indexed(
  String name, {
  int mtime = 1000,
  int size = 100,
  String type = 'video',
}) {
  return MediaIndex(
    path: '/test/$name',
    filename: name,
    modifiedAt: mtime,
    size: size,
    durationMs: 0,
    mediaType: type,
    indexedAt: 0,
  );
}

void main() {
  group('LibraryScanService', () {
    test('first scan inserts every reported file', () async {
      final store = _InMemoryStore();
      final source = _ListSource([
        _entry('a.mp4'),
        _entry('b.mp3', type: 'audio'),
        _entry('c.jpg', type: 'image'),
      ]);
      final service = LibraryScanService(source, store);

      final events = await service.scan().toList();
      final done = events.last;

      expect(done.done, isTrue);
      expect(done.newItemsFound, 3);
      expect(done.updatedItems, 0);
      expect(done.removedItems, 0);
      expect(store.data.length, 3);
    });

    test('subsequent scan detects deletions', () async {
      final store = _InMemoryStore()
        ..data['/test/a.mp4'] = _indexed('a.mp4')
        ..data['/test/b.mp4'] = _indexed('b.mp4');

      // Device only reports a.mp4 now — b.mp4 was deleted.
      final source = _ListSource([_entry('a.mp4')]);
      final events =
          await LibraryScanService(source, store).scan().toList();
      final done = events.last;

      expect(done.removedItems, 1);
      expect(store.data.containsKey('/test/a.mp4'), isTrue);
      expect(store.data.containsKey('/test/b.mp4'), isFalse);
    });

    test('unchanged files perform zero DB writes', () async {
      final store = _InMemoryStore()
        ..data['/test/a.mp4'] = _indexed('a.mp4', mtime: 1000, size: 100)
        ..data['/test/b.mp4'] = _indexed('b.mp4', mtime: 2000, size: 200);

      final source = _ListSource([
        _entry('a.mp4', mtime: 1000, size: 100),
        _entry('b.mp4', mtime: 2000, size: 200),
      ]);

      final events =
          await LibraryScanService(source, store).scan().toList();
      final done = events.last;

      expect(done.newItemsFound, 0);
      expect(done.updatedItems, 0);
      expect(done.removedItems, 0);
      expect(store.upsertCalls, 0, reason: 'no writes for unchanged scan');
      expect(store.removeCalls, 0);
    });

    test('size or mtime change triggers an update', () async {
      final store = _InMemoryStore()
        ..data['/test/a.mp4'] = _indexed('a.mp4', mtime: 1000, size: 100);

      // mtime changed → re-indexed.
      final source = _ListSource([_entry('a.mp4', mtime: 9999, size: 100)]);
      final events =
          await LibraryScanService(source, store).scan().toList();
      final done = events.last;

      expect(done.newItemsFound, 0);
      expect(done.updatedItems, 1);
      expect(store.data['/test/a.mp4']!.modifiedAt, 9999);
    });

    test('large-library scan stays batched and within budget', () async {
      final store = _InMemoryStore();
      final entries = List.generate(
        10000,
        (i) => _entry('f$i.mp4', mtime: 1000 + i, size: 100 + i),
      );

      final sw = Stopwatch()..start();
      final events = <ScanProgress>[];
      await for (final p in LibraryScanService(_ListSource(entries), store)
          .scan(batchSize: 500, yieldEveryNFiles: 250)) {
        events.add(p);
      }
      sw.stop();

      expect(events.last.done, isTrue);
      expect(events.last.newItemsFound, 10000);
      expect(store.data.length, 10000);
      // Multiple in-flight progress events plus the start + done frame.
      expect(events.length, greaterThan(10));
      // 10k in-memory entries should finish well under a few seconds.
      expect(
        sw.elapsed.inSeconds,
        lessThan(5),
        reason: 'large-library scan took ${sw.elapsedMilliseconds}ms',
      );
      // Persistence happened in chunks, not one-at-a-time.
      expect(store.upsertCalls, lessThanOrEqualTo(10000 ~/ 500 + 1));
    });
  });
}
