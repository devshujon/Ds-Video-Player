import 'dart:math';

import 'media_signal.dart';

/// A media URI with its computed recommendation score.
class ScoredMedia {
  const ScoredMedia(this.uri, this.score);
  final String uri;
  final double score;
}

/// On-device recommendation engine. Pure, deterministic, no network.
///
/// score(item) = base(item) · recencyDecay(age)
///
///   base       = playCount·playWeight
///              + (completed  ? completeWeight : 0)
///              + (favorite   ? favoriteWeight : 0)
///   recencyDecay = 0.5 ^ (age / halfLife)   — exponential, halves every
///                                              [halfLife].
///
/// Recent, repeated, completed and favourited media float to the top;
/// stale interactions fade. Items with a non-positive base are dropped.
class Recommender {
  const Recommender({
    this.halfLife = const Duration(days: 21),
    this.playWeight = 1.0,
    this.completeWeight = 2.0,
    this.favoriteWeight = 3.0,
  });

  final Duration halfLife;
  final double playWeight;
  final double completeWeight;
  final double favoriteWeight;

  List<ScoredMedia> rank(
    List<MediaSignal> signals, {
    DateTime? now,
    int limit = 20,
  }) {
    final ref = (now ?? DateTime.now()).millisecondsSinceEpoch;

    final scored = <ScoredMedia>[];
    for (final s in signals) {
      final base = s.playCount * playWeight +
          (s.completed ? completeWeight : 0.0) +
          (s.isFavorite ? favoriteWeight : 0.0);
      if (base <= 0) continue;
      scored.add(
        ScoredMedia(s.uri, base * _decay(ref - s.lastInteractionMs)),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList(growable: false);
  }

  double _decay(int ageMs) {
    if (ageMs <= 0) return 1.0; // future/now timestamps: no decay
    return pow(0.5, ageMs / halfLife.inMilliseconds).toDouble();
  }
}
