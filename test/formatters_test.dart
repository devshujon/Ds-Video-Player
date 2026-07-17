import 'dart:io';

import 'package:ds_video_player/core/constants/media_formats.dart';
import 'package:ds_video_player/core/utils/formatters.dart';
import 'package:ds_video_player/features/player/domain/services/subtitle_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formatters.duration', () {
    test('formats sub-hour as mm:ss', () {
      expect(Formatters.duration(const Duration(minutes: 3, seconds: 7)),
          '03:07');
    });
    test('formats hours as h:mm:ss', () {
      expect(
        Formatters.duration(
            const Duration(hours: 1, minutes: 2, seconds: 9)),
        '1:02:09',
      );
    });
  });

  group('Formatters.fileSize', () {
    test('bytes', () => expect(Formatters.fileSize(512), '512 B'));
    test('mega', () => expect(Formatters.fileSize(5 * 1024 * 1024), '5.0 MB'));
    test('zero/negative', () => expect(Formatters.fileSize(0), '0 B'));
  });

  group('Formatters.progress', () {
    test('clamps to 0..1', () {
      expect(Formatters.progress(50, 100), 0.5);
      expect(Formatters.progress(200, 100), 1.0);
      expect(Formatters.progress(10, 0), 0.0);
    });
  });

  group('MediaFormats.classify', () {
    test('detects containers/codecs by extension', () {
      expect(MediaFormats.classify('/x/a.mkv'), MediaType.video);
      expect(MediaFormats.classify('/x/b.FLAC'), MediaType.audio);
      expect(MediaFormats.classify('/x/c.heic'), MediaType.image);
      expect(MediaFormats.classify('/x/d.unknown'), isNull);
    });
    test('subtitle detection', () {
      expect(MediaFormats.isSubtitle('movie.srt'), isTrue);
      expect(MediaFormats.isSubtitle('movie.mp4'), isFalse);
    });
  });

  group('SubtitleResolver', () {
    test('finds sidecar subtitle by basename', () async {
      final dir = await Directory.systemTemp.createTemp('subres');
      try {
        final media = File('${dir.path}/movie.mp4');
        await media.create();
        final srt = File('${dir.path}/movie.srt');
        await srt.create();
        expect(await SubtitleResolver.findFor(media.path), srt.path);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('returns null when no sidecar exists', () async {
      final dir = await Directory.systemTemp.createTemp('subres');
      try {
        final media = File('${dir.path}/movie.mp4');
        await media.create();
        expect(await SubtitleResolver.findFor(media.path), isNull);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
