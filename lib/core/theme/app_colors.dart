import 'package:flutter/material.dart';

/// Brand palette. Accent is a confident violet/indigo — premium, modern,
/// readable on light, dark and pure-black (AMOLED) surfaces.
class AppColors {
  AppColors._();

  static const Color brandPrimary = Color(0xFF6C5CE7);
  static const Color brandSecondary = Color(0xFF00CEC9);
  static const Color brandError = Color(0xFFFF6B6B);

  // AMOLED true black for OLED battery savings.
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0A0A0A);

  static const Color darkBackground = Color(0xFF121317);
  static const Color darkSurface = Color(0xFF1B1D23);

  static const Color lightBackground = Color(0xFFF7F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
}

enum AppThemeMode { light, dark, amoled }
