import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/di/service_locator.dart';
import 'features/ads/data/ad_service.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();

    await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp],
    );

    await ServiceLocator.init();

    unawaited(sl<AdService>().init());

    runApp(
      const ProviderScope(
        child: DSVideoPlayerApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}
