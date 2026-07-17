import 'dart:io';

import 'package:ds_video_player/app/di/service_locator.dart';
import 'package:ds_video_player/core/constants/app_constants.dart';
import 'package:ds_video_player/core/services/premium_token_store.dart';
import 'package:ds_video_player/core/services/thumbnail_cache_service.dart';
import 'package:ds_video_player/features/media_library/presentation/providers/media_library_provider.dart';
import 'package:ds_video_player/features/media_library/presentation/screens/home_screen.dart';
import 'package:ds_video_player/features/premium/data/iap_product.dart';
import 'package:ds_video_player/features/premium/data/iap_service.dart';
import 'package:ds_video_player/features/premium/presentation/providers/premium_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_media_library.dart';

class _FakeStore implements PremiumTokenStore {
  @override
  Future<String?> readPremiumToken() async => 'premium';
  @override
  Future<void> writePremiumToken(String t) async {}
}

class _NoIap implements IapService {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<List<IapProduct>> loadProducts() async => const [];
  @override
  Future<void> purchase(IapProduct product) async {}
  @override
  Future<void> restore() async {}
  @override
  Stream<IapPurchase> get purchaseStream => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory thumbDir;

  setUpAll(() async {
    thumbDir = await Directory.systemTemp.createTemp('home_nav_thumbs');
    if (!sl.isRegistered<ThumbnailCacheService>()) {
      sl.registerSingleton<ThumbnailCacheService>(
        ThumbnailCacheService(overrideDir: thumbDir),
      );
    }
  });

  tearDownAll(() async {
    if (sl.isRegistered<ThumbnailCacheService>()) {
      await sl.unregister<ThumbnailCacheService>();
    }
    if (thumbDir.existsSync()) {
      await thumbDir.delete(recursive: true);
    }
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    required PremiumProvider premium,
    required MediaLibraryProvider library,
    Key? homeKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<PremiumProvider>.value(value: premium),
            ChangeNotifierProvider<MediaLibraryProvider>.value(value: library),
          ],
          child: HomeScreen(key: homeKey),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('HomeScreen startup navigation', () {
    late PremiumProvider premium;
    late MediaLibraryProvider library;

    setUp(() async {
      premium = PremiumProvider(_FakeStore(), _NoIap());
      await premium.init();
      library = createTestMediaLibraryProvider();
    });

    testWidgets('cold start shows Home Dashboard, not Videos tab', (tester) async {
      await pumpHome(tester, premium: premium, library: library);

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Library summary'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.indicatorColor, Colors.transparent);
    });

    testWidgets('tapping Videos opens the Videos library tab', (tester) async {
      await pumpHome(tester, premium: premium, library: library);

      await tester.tap(find.text('Videos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(AppConstants.appName), findsNothing);
      expect(find.text('Library summary'), findsNothing);

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.indicatorColor, isNot(Colors.transparent));
    });

    testWidgets('tapping app title returns to Home Dashboard', (tester) async {
      await pumpHome(tester, premium: premium, library: library);

      await tester.tap(find.text('Folders'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Library summary'), findsNothing);

      await tester.tap(find.byKey(const Key('home_shell_title')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Library summary'), findsOneWidget);
    });

    testWidgets('session tab survives widget rebuild (background resume)', (
      tester,
    ) async {
      await pumpHome(tester, premium: premium, library: library);

      await tester.tap(find.text('Audio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Library summary'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<PremiumProvider>.value(value: premium),
              ChangeNotifierProvider<MediaLibraryProvider>.value(
                value: library,
              ),
            ],
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Library summary'), findsNothing);
      expect(find.text('Audio'), findsWidgets);
    });

    testWidgets('new HomeScreen after kill returns to dashboard', (tester) async {
      await pumpHome(tester, premium: premium, library: library);

      await tester.tap(find.text('Downloads'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Library summary'), findsNothing);

      await pumpHome(
        tester,
        premium: premium,
        library: library,
        homeKey: const ValueKey('fresh-launch'),
      );

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Library summary'), findsOneWidget);
    });
  });
}
