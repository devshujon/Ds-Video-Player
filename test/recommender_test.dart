import 'package:ds_video_player/features/recommendations/domain/media_signal.dart';
import 'package:ds_video_player/features/recommendations/domain/recommender.dart';
import 'package:flutter_test/flutter_test.dart';

MediaSignal sig(
  String uri, {
  int lastMs = 0,
  int playCount = 0,
  bool completed = false,
  bool favorite = false,
}) =>
    MediaSignal(
      uri: uri,
      lastInteractionMs: lastMs,
      playCount: playCount,
      completed: completed,
      isFavorite: favorite,
    );

void main() {
  final now = DateTime(2026, 1, 1, 12);

  group('Recommender.rank', () {
    test('empty input yields empty output', () {
      expect(const Recommender().rank([], now: now), isEmpty);
    });

    test('drops signals with a non-positive base score', () {
      // playCount 0, not completed, not favourite → base 0 → excluded.
      final out = const Recommender().rank(
        [sig('/x', lastMs: now.millisecondsSinceEpoch)],
        now: now,
      );
      expect(out, isEmpty);
    });

    test('a favourite-only item is recommended', () {
      final out = const Recommender().rank(
        [sig('/fav', lastMs: now.millisecondsSinceEpoch, favorite: true)],
        now: now,
      );
      expect(out, hasLength(1));
      expect(out.first.uri, '/fav');
      expect(out.first.score, closeTo(3.0, 0.001)); // favoriteWeight, no decay
    });

    test('recency decay halves the score at exactly one half-life', () {
      const rec = Recommender(halfLife: Duration(days: 21));
      final oneHalfLifeAgo = now.subtract(const Duration(days: 21));
      final out = rec.rank(
        [
          sig('/old',
              lastMs: oneHalfLifeAgo.millisecondsSinceEpoch, favorite: true),
        ],
        now: now,
      );
      expect(out.first.score, closeTo(1.5, 0.01)); // 3 · 0.5
    });

    test('more recent interaction outranks an older one of equal base', () {
      const rec = Recommender();
      final recent = now.subtract(const Duration(days: 1));
      final old = now.subtract(const Duration(days: 90));
      final out = rec.rank(
        [
          sig('/old', lastMs: old.millisecondsSinceEpoch, favorite: true),
          sig('/recent',
              lastMs: recent.millisecondsSinceEpoch, favorite: true),
        ],
        now: now,
      );
      expect(out.first.uri, '/recent');
      expect(out.last.uri, '/old');
    });

    test('completed playback adds the complete weight', () {
      const rec = Recommender();
      final t = now.millisecondsSinceEpoch;
      final out = rec.rank(
        [
          sig('/a', lastMs: t, playCount: 1), // base 1
          sig('/b', lastMs: t, playCount: 1, completed: true), // base 1+2
        ],
        now: now,
      );
      expect(out.first.uri, '/b');
      expect(out.first.score, closeTo(3.0, 0.001));
      expect(out.last.score, closeTo(1.0, 0.001));
    });

    test('play count multiplies the play weight', () {
      const rec = Recommender();
      final out = rec.rank(
        [sig('/a', lastMs: now.millisecondsSinceEpoch, playCount: 5)],
        now: now,
      );
      expect(out.first.score, closeTo(5.0, 0.001));
    });

    test('respects the result limit, keeping the top scorers', () {
      const rec = Recommender();
      final t = now.millisecondsSinceEpoch;
      final signals = List.generate(
        30,
        (i) => sig('/m$i', lastMs: t, playCount: i + 1),
      );
      final out = rec.rank(signals, now: now, limit: 10);
      expect(out, hasLength(10));
      expect(out.first.uri, '/m29'); // highest play count
    });

    test('a future timestamp does not amplify the score', () {
      const rec = Recommender();
      final future = now.add(const Duration(days: 5));
      final out = rec.rank(
        [sig('/f', lastMs: future.millisecondsSinceEpoch, favorite: true)],
        now: now,
      );
      expect(out.first.score, closeTo(3.0, 0.001)); // decay clamped to 1.0
    });
  });
}
