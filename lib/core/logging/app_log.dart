import 'package:flutter/foundation.dart';

/// Release-safe logging — silent in profile/release builds.
abstract final class AppLog {
  static void warn(String message, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[DS] $message${error != null ? ': $error' : ''}');
      if (stack != null) debugPrint(stack.toString());
    }
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[DS][ERROR] $message${error != null ? ': $error' : ''}');
      if (stack != null) debugPrint(stack.toString());
    }
  }
}
