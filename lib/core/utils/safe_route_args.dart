import 'package:flutter/material.dart';

/// Defensive route-argument parsing — avoids unsafe `as` casts in the router.
T? routeArg<T>(RouteSettings settings) {
  final args = settings.arguments;
  return args is T ? args : null;
}
