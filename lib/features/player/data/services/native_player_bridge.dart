import 'dart:async';

import 'package:flutter/services.dart';

/// Native Android bridge for Picture-in-Picture and lifecycle signals.
class NativePlayerBridge {
  NativePlayerBridge._();

  static const _channel = MethodChannel('com.devshujon.ds_video_player/player');

  static final StreamController<bool> _pipController =
      StreamController<bool>.broadcast();

  static Stream<bool> get pipModeStream => _pipController.stream;
  static bool isInPipMode = false;

  static bool _handlerRegistered = false;

  static void ensureHandler() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        isInPipMode = call.arguments as bool? ?? false;
        _pipController.add(isInPipMode);
      }
    });
  }

  static Future<bool> isPipSupported() async {
    ensureHandler();
    final supported = await _channel.invokeMethod<bool>('isPipSupported');
    return supported ?? false;
  }

  static Future<bool> enterPip() async {
    ensureHandler();
    final ok = await _channel.invokeMethod<bool>('enterPip');
    return ok ?? false;
  }

  static Future<void> setAutoPipOnLeave(bool enabled) async {
    ensureHandler();
    await _channel.invokeMethod<void>('setAutoPipOnLeave', enabled);
  }

  static Future<bool> queryInPipMode() async {
    ensureHandler();
    final v = await _channel.invokeMethod<bool>('isInPipMode');
    return v ?? false;
  }
}
