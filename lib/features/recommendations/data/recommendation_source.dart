import '../../../../core/database/app_database.dart';
import '../domain/media_signal.dart';

/// Supplies the [MediaSignal]s the recommender scores. Abstracted so the
/// recommender pipeline can be tested with an in-memory fake.
abstract interface class RecommendationSource {
  Future<List<MediaSignal>> signals();
}

/// Reads signals from the tables the app already maintains:
/// `playback_history` (recency, play_count, completed) merged with
/// `favorites` (a strong like signal). A favourited item with no playback
/// history still contributes a signal.
class SqliteRecommendationSource implements RecommendationSource {
  SqliteRecommendationSource(this._db);
  final AppDatabase _db;

  @override
  Future<List<MediaSignal>> signals() async {
    final db = await _db.database;

    final history = await db.query(
      'playback_history',
      columns: ['media_uri', 'played_at', 'play_count', 'completed'],
    );
    final favorites = await db.query(
      'favorites',
      columns: ['media_uri', 'added_at'],
    );

    final byUri = <String, _Acc>{};
    for (final row in history) {
      final uri = row['media_uri'] as String;
      byUri[uri] = _Acc(
        lastInteractionMs: (row['played_at'] as int?) ?? 0,
        playCount: (row['play_count'] as int?) ?? 0,
        completed: (row['completed'] as int?) == 1,
        isFavorite: false,
      );
    }
    for (final row in favorites) {
      final uri = row['media_uri'] as String;
      final addedAt = (row['added_at'] as int?) ?? 0;
      final existing = byUri[uri];
      if (existing == null) {
        byUri[uri] = _Acc(
          lastInteractionMs: addedAt,
          playCount: 0,
          completed: false,
          isFavorite: true,
        );
      } else {
        existing
          ..isFavorite = true
          ..lastInteractionMs =
              addedAt > existing.lastInteractionMs
                  ? addedAt
                  : existing.lastInteractionMs;
      }
    }

    return byUri.entries
        .map((e) => MediaSignal(
              uri: e.key,
              lastInteractionMs: e.value.lastInteractionMs,
              playCount: e.value.playCount,
              completed: e.value.completed,
              isFavorite: e.value.isFavorite,
            ))
        .toList(growable: false);
  }
}

class _Acc {
  _Acc({
    required this.lastInteractionMs,
    required this.playCount,
    required this.completed,
    required this.isFavorite,
  });
  int lastInteractionMs;
  int playCount;
  bool completed;
  bool isFavorite;
}
