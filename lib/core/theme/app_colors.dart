import 'package:flutter/material.dart';

/// Brand palette — royal purple family. Flat, premium, readable on
/// light, dark and AMOLED surfaces.
class AppColors {
  AppColors._();

  static const Color brandPrimary = Color(0xFF6C5CE7);
  static const Color brandSecondary = Color(0xFF8B5CF6);
  static const Color brandAccent = Color(0xFFA78BFA);
  static const Color brandPremium = Color(0xFFC4B5FD);
  static const Color brandDark = Color(0xFF0F1117);
  static const Color brandWhite = Color(0xFFFFFFFF);
  static const Color brandError = Color(0xFFFF6B6B);

  // AMOLED true black for OLED battery savings.
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0A0A0A);

  static const Color darkBackground = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF1B1D23);

  static const Color lightBackground = Color(0xFFF7F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
}

enum AppThemeMode { light, dark, amoled }
