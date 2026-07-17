import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All non-secret user preferences. Persisted to shared_preferences.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs);
  final SharedPreferences _prefs;

  bool get resumePlayback => _prefs.getBool(_kResume) ?? true;
  bool get backgroundAudio => _prefs.getBool(_kBgAudio) ?? true;
  bool get gesturesEnabled => _prefs.getBool(_kGestures) ?? true;
  bool get autoPlayNext => _prefs.getBool(_kAutoNext) ?? true;
  bool get forceSoftwareDecode => _prefs.getBool(_kForceSw) ?? false;
  bool get rotationLocked => _prefs.getBool(_kRotLock) ?? false;
  int get seekSeconds => _prefs.getInt(_kSeek) ?? 10;

  static const _kResume = 's_resume';
  static const _kBgAudio = 's_bg_audio';
  static const _kGestures = 's_gestures';
  static const _kAutoNext = 's_auto_next';
  static const _kForceSw = 's_force_sw';
  static const _kRotLock = 's_rotation_lock';
  static const _kSeek = 's_seek';

  Future<void> setResume(bool v) => _set(_kResume, v);
  Future<void> setBackgroundAudio(bool v) => _set(_kBgAudio, v);
  Future<void> setGestures(bool v) => _set(_kGestures, v);
  Future<void> setAutoPlayNext(bool v) => _set(_kAutoNext, v);
  Future<void> setForceSoftwareDecode(bool v) => _set(_kForceSw, v);
  Future<void> setRotationLocked(bool v) => _set(_kRotLock, v);

  Future<void> setSeekSeconds(int v) async {
    await _prefs.setInt(_kSeek, v);
    notifyListeners();
  }

  Future<void> _set(String key, bool v) async {
    await _prefs.setBool(key, v);
    notifyListeners();
  }
}
