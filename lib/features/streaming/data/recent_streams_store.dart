import 'package:shared_preferences/shared_preferences.dart';

/// Most-recently-used network stream URLs, persisted to shared_preferences.
/// Most-recent first, de-duplicated, capped at [maxEntries].
class RecentStreamsStore {
  RecentStreamsStore(this._prefs);
  final SharedPreferences _prefs;

  static const String _key = 'recent_stream_urls';
  static const int maxEntries = 10;

  List<String> all() => _prefs.getStringList(_key) ?? const [];

  Future<void> add(String url) async {
    final next = <String>[
      url,
      ...all().where((u) => u != url),
    ].take(maxEntries).toList(growable: false);
    await _prefs.setStringList(_key, next);
  }

  Future<void> remove(String url) async {
    await _prefs.setStringList(
      _key,
      all().where((u) => u != url).toList(growable: false),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
