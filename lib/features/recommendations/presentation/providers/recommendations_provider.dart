import 'package:flutter/foundation.dart';

import '../../data/recommendation_source.dart';
import '../../domain/recommender.dart';

/// Route-scoped state for the "Suggested for you" screen.
class RecommendationsProvider extends ChangeNotifier {
  RecommendationsProvider(this._source, this._recommender);

  final RecommendationSource _source;
  final Recommender _recommender;

  // M1 — lifecycle guard: load() can resolve after the route is popped.
  bool _disposed = false;

  bool isLoading = true;
  List<ScoredMedia> ranked = const [];

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final signals = await _source.signals();
    ranked = _recommender.rank(signals);
    isLoading = false;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
