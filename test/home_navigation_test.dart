import 'dart:io';

import 'package:ds_video_player/app/di/service_locator.dart';
import 'package:ds_video_player/app/router/app_router.dart';
import 'package:ds_video_player/app/router/route_names.dart';
import 'package:ds_video_player/core/constants/app_constants.dart';
import 'package:ds_video_player/core/services/premium_token_store.dart';
import 'package:ds_video_player/core/services/thumbnail_cache_service.dart';
import 'package:ds_video_player/features/media_library/presentation/providers/media_library_provider.dart';
import 'package:ds_video_player/features/media_library/presentation/screens/home_dashboard_screen.dart';
import 'package:ds_video_player/features/media_library/presentation/screens/library_page_screen.dart';
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

  Future<void> pumpApp(
    WidgetTester tester, {
    required PremiumProvider premium,
    required MediaLibraryProvider library,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumProvider>.value(value: premium),
          ChangeNotifierProvider<MediaLibraryProvider>.value(value: library),
        ],
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomeDashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('Home navigation architecture', () {
    late PremiumProvider premium;
    late MediaLibraryProvider library;

    setUp(() async {
      premium = PremiumProvider(_FakeStore(), _NoIap());
      await premium.init();
      library = createTestMediaLibraryProvider();
    });

    testWidgets('fresh launch shows standalone Home Dashboard without tabs', (
      tester,
    ) async {
      await pumpApp(tester, premium: premium, library: library);

      expect(find.byType(HomeDashboardScreen), findsOneWidget);
      expect(find.byType(LibraryPageScreen), findsNothing);
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Library summary'), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('All videos'), findsNothing);
    });

    testWidgets('Videos quick action opens dedicated library page', (
      tester,
    ) async {
      await pumpApp(tester, premium: premium, library: library);

      await tester.tap(find.bySemanticsLabel('Open Videos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LibraryPageScreen), findsOneWidget);
      expect(find.text('All videos'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('back from Videos returns to Home Dashboard', (tester) async {
      await pumpApp(tester, premium: premium, library: library);

      await tester.tap(find.bySemanticsLabel('Open Videos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(
        find.descendant(
          of: find.byType(LibraryPageScreen),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Quick actions'), findsOneWidget);
    });

    testWidgets('background resume keeps library route on navigator stack', (
      tester,
    ) async {
      await pumpApp(tester, premium: premium, library: library);

      await tester.tap(find.bySemanticsLabel('Open Audio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LibraryPageScreen), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.byType(LibraryPageScreen), findsOneWidget);
      expect(find.text('Audio'), findsWidgets);
    });
  });
}
