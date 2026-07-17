import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/playback_state.dart';

/// Per-URI playback preferences persisted locally for instant resume.
class PlaybackStateStore {
  PlaybackStateStore(this._prefs);

  final SharedPreferences _prefs;
  static const _prefix = 'playback_state_v1_';

  String _key(String uri) =>
      '$_prefix${sha256.convert(uri.codeUnits).toString().substring(0, 20)}';

  Future<PlaybackState?> load(String uri) async {
    final raw = _prefs.getString(_key(uri));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, Object?>;
      return PlaybackState.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String uri, PlaybackState state) async {
    await _prefs.setString(_key(uri), jsonEncode(state.toJson()));
  }

  Future<void> clear(String uri) async {
    await _prefs.remove(_key(uri));
  }
}
