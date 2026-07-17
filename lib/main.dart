import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/di/service_locator.dart';
import 'core/logging/app_log.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    final startup = Stopwatch()..start();
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();

    await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp],
    );

    await ServiceLocator.init();
    startup.stop();
    AppLog.warn('Cold startup (init only): ${startup.elapsedMilliseconds}ms');

    runApp(const DSVideoPlayerApp());
  }, (error, stack) {
    AppLog.error('Uncaught zone error', error, stack);
  });
}
