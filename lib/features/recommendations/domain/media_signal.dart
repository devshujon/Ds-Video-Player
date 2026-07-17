/// A per-media usage signal, aggregated from the data the app already
/// records — `playback_history` and `favorites`. No separate event log is
/// needed: every play already writes history, every favorite a row.
class MediaSignal {
  const MediaSignal({
    required this.uri,
    required this.lastInteractionMs,
    required this.playCount,
    required this.completed,
    required this.isFavorite,
  });

  final String uri;

  /// Epoch ms of the most recent interaction (last played, or favourited).
  /// Drives the recency decay.
  final int lastInteractionMs;

  final int playCount;

  /// True if the user watched/listened to (near) the end at least once.
  final bool completed;

  final bool isFavorite;
}
