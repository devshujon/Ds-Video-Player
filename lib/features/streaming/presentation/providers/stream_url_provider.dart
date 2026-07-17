import 'package:flutter/foundation.dart';

import '../../data/recent_streams_store.dart';

/// Route-scoped state for the "Open network URL" screen: the recent-URL
/// history plus mutation helpers.
class StreamUrlProvider extends ChangeNotifier {
  StreamUrlProvider(this._store) {
    recent = _store.all();
  }

  final RecentStreamsStore _store;
  List<String> recent = const [];

  /// Records [url] as the most-recent stream.
  Future<void> remember(String url) async {
    await _store.add(url);
    recent = _store.all();
    notifyListeners();
  }

  Future<void> forget(String url) async {
    await _store.remove(url);
    recent = _store.all();
    notifyListeners();
  }

  Future<void> clear() async {
    await _store.clear();
    recent = const [];
    notifyListeners();
  }
}
