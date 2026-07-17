import 'package:ds_video_player/core/services/premium_token_store.dart';
import 'package:ds_video_player/features/ads/presentation/widgets/banner_ad_view.dart';
import 'package:ds_video_player/features/premium/data/iap_product.dart';
import 'package:ds_video_player/features/premium/data/iap_service.dart';
import 'package:ds_video_player/features/premium/presentation/providers/premium_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

class _FakeStore implements PremiumTokenStore {
  _FakeStore({this.token});
  String? token;
  @override
  Future<String?> readPremiumToken() async => token;
  @override
  Future<void> writePremiumToken(String t) async => token = t;
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
  Stream<IapPurchase> get purchaseStream => const Stream<IapPurchase>.empty();
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'BannerAdView never loads or renders an ad for premium users',
    (tester) async {
      final premium = PremiumProvider(
        _FakeStore(token: 'cached-premium-token'),
        _NoIap(),
      );
      await premium.init(); // isPremium → true, showAds → false

      expect(premium.isPremium, isTrue);
      expect(premium.showAds, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PremiumProvider>.value(
            value: premium,
            child: const Scaffold(body: BannerAdView()),
          ),
        ),
      );

      // The widget itself mounts...
      expect(find.byType(BannerAdView), findsOneWidget);
      // ...but no AdWidget should ever be created (load is gated on showAds
      // in initState — paying users never trigger a network ad request).
      expect(find.byType(AdWidget), findsNothing);
    },
  );
}
