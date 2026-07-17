import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'app_theme.dart';

/// Owns the active theme. Persisted to shared_preferences so the choice
/// survives restarts. AMOLED is gated as a premium perk by the UI.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    final raw = _prefs.getString(_key);
    _mode = AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.dark,
    );
  }

  static const String _key = 'app_theme_mode';
  final SharedPreferences _prefs;
  AppThemeMode _mode = AppThemeMode.dark;

  AppThemeMode get mode => _mode;

  ThemeData get themeData => switch (_mode) {
        AppThemeMode.light => AppTheme.light(),
        AppThemeMode.dark => AppTheme.dark(),
        AppThemeMode.amoled => AppTheme.amoled(),
      };

  bool get isDark => _mode != AppThemeMode.light;

  Future<void> setMode(AppThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _prefs.setString(_key, mode.name);
  }
}
