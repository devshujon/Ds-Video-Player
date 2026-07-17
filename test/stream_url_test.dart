import 'package:ds_video_player/features/streaming/data/recent_streams_store.dart';
import 'package:ds_video_player/features/streaming/data/stream_url.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StreamUrl.isValid', () {
    test('accepts http and https', () {
      expect(StreamUrl.isValid('http://example.com/a.mp4'), isTrue);
      expect(StreamUrl.isValid('https://example.com/live.m3u8'), isTrue);
    });

    test('accepts rtsp and rtmp', () {
      expect(StreamUrl.isValid('rtsp://10.0.0.1/cam'), isTrue);
      expect(StreamUrl.isValid('rtmp://a.example.com/live'), isTrue);
    });

    test('rejects unsupported schemes', () {
      expect(StreamUrl.isValid('ftp://example.com/x'), isFalse);
      expect(StreamUrl.isValid('file:///sdcard/x.mp4'), isFalse);
    });

    test('rejects malformed / schemeless / hostless input', () {
      expect(StreamUrl.isValid(''), isFalse);
      expect(StreamUrl.isValid('   '), isFalse);
      expect(StreamUrl.isValid('example.com/x'), isFalse);
      expect(StreamUrl.isValid('http://'), isFalse);
    });

    test('tolerates surrounding whitespace', () {
      expect(StreamUrl.isValid('  https://example.com/x  '), isTrue);
    });
  });

  group('StreamUrl.titleFor', () {
    test('uses the last path segment', () {
      expect(
        StreamUrl.titleFor('https://cdn.example.com/movies/clip.mp4'),
        'clip.mp4',
      );
    });

    test('falls back to host when there is no path', () {
      expect(StreamUrl.titleFor('https://example.com'), 'example.com');
    });
  });

  group('RecentStreamsStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<RecentStreamsStore> store() async =>
        RecentStreamsStore(await SharedPreferences.getInstance());

    test('add prepends most-recent and persists', () async {
      final s = await store();
      await s.add('https://a.com/1');
      await s.add('https://b.com/2');
      expect(s.all(), ['https://b.com/2', 'https://a.com/1']);
    });

    test('add de-duplicates and moves an existing url to the front',
        () async {
      final s = await store();
      await s.add('https://a.com/1');
      await s.add('https://b.com/2');
      await s.add('https://a.com/1');
      expect(s.all(), ['https://a.com/1', 'https://b.com/2']);
    });

    test('caps history at maxEntries', () async {
      final s = await store();
      for (var i = 0; i < RecentStreamsStore.maxEntries + 5; i++) {
        await s.add('https://example.com/$i');
      }
      expect(s.all(), hasLength(RecentStreamsStore.maxEntries));
      expect(
        s.all().first,
        'https://example.com/${RecentStreamsStore.maxEntries + 4}',
      );
    });

    test('remove drops one entry; clear empties the list', () async {
      final s = await store();
      await s.add('https://a.com/1');
      await s.add('https://b.com/2');
      await s.remove('https://a.com/1');
      expect(s.all(), ['https://b.com/2']);
      await s.clear();
      expect(s.all(), isEmpty);
    });
  });
}
