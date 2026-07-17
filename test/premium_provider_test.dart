import 'dart:async';

import 'package:ds_video_player/core/services/premium_token_store.dart';
import 'package:ds_video_player/features/premium/data/iap_product.dart';
import 'package:ds_video_player/features/premium/data/iap_service.dart';
import 'package:ds_video_player/features/premium/presentation/providers/premium_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements PremiumTokenStore {
  String? token;
  @override
  Future<String?> readPremiumToken() async => token;
  @override
  Future<void> writePremiumToken(String t) async => token = t;
}

class _FakeIap implements IapService {
  final StreamController<IapPurchase> _ctrl =
      StreamController<IapPurchase>.broadcast();
  bool available = true;
  List<IapProduct> productsToReturn = const [];
  int purchaseCalls = 0;
  int restoreCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<IapProduct>> loadProducts() async => productsToReturn;

  @override
  Future<void> purchase(IapProduct product) async {
    purchaseCalls++;
  }

  @override
  Future<void> restore() async {
    restoreCalls++;
  }

  @override
  Stream<IapPurchase> get purchaseStream => _ctrl.stream;

  @override
  Future<void> dispose() async {
    await _ctrl.close();
  }

  void emit(IapPurchase p) => _ctrl.add(p);
}

/// Give the broadcast stream + async listener a tick to run.
Future<void> _pumpEvents() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  group('PremiumProvider', () {
    test('init() restores premium from cached token', () async {
      final store = _FakeStore()..token = 'cached-token';
      final p = PremiumProvider(store, _FakeIap());
      await p.init();
      expect(p.isPremium, isTrue);
      expect(p.showAds, isFalse);
    });

    test('init() without cached token leaves user free-tier', () async {
      final p = PremiumProvider(_FakeStore(), _FakeIap());
      await p.init();
      expect(p.isPremium, isFalse);
      expect(p.showAds, isTrue);
    });

    test('init() loads products when billing available', () async {
      final iap = _FakeIap()
        ..productsToReturn = const [
          IapProduct(
            id: 'ds_premium_lifetime',
            title: 'Lifetime',
            description: 'One-time',
            price: '\$4.99',
            type: IapProductType.lifetime,
          ),
        ];
      final p = PremiumProvider(_FakeStore(), iap);
      await p.init();
      expect(p.isBillingAvailable, isTrue);
      expect(p.products, hasLength(1));
      expect(p.products.first.id, 'ds_premium_lifetime');
    });

    test('billing-unavailable: products empty, billing flag false', () async {
      final p = PremiumProvider(_FakeStore(), _FakeIap()..available = false);
      await p.init();
      expect(p.isBillingAvailable, isFalse);
      expect(p.products, isEmpty);
    });

    test('successful purchase event flips premium + writes token', () async {
      final store = _FakeStore();
      final iap = _FakeIap();
      final p = PremiumProvider(store, iap);
      await p.init();

      iap.emit(const IapPurchase(
        productId: 'ds_premium_lifetime',
        status: IapPurchaseStatus.success,
        verificationToken: 'verified-abc',
      ));
      await _pumpEvents();

      expect(p.isPremium, isTrue);
      expect(p.isPurchasing, isFalse);
      expect(store.token, 'verified-abc');
    });

    test('restored event also grants premium', () async {
      final store = _FakeStore();
      final iap = _FakeIap();
      final p = PremiumProvider(store, iap);
      await p.init();

      iap.emit(const IapPurchase(
        productId: 'ds_premium_yearly',
        status: IapPurchaseStatus.restored,
        verificationToken: 'restored-xyz',
      ));
      await _pumpEvents();

      expect(p.isPremium, isTrue);
      expect(store.token, 'restored-xyz');
    });

    test('error event surfaces errorText, does not grant premium',
        () async {
      final iap = _FakeIap();
      final p = PremiumProvider(_FakeStore(), iap);
      await p.init();

      iap.emit(const IapPurchase(
        productId: 'ds_premium_monthly',
        status: IapPurchaseStatus.error,
        error: 'network down',
      ));
      await _pumpEvents();

      expect(p.isPremium, isFalse);
      expect(p.errorText, contains('network'));
    });

    test('cancel event clears purchasing state without granting', () async {
      final iap = _FakeIap();
      final p = PremiumProvider(_FakeStore(), iap);
      await p.init();

      await p.purchase(const IapProduct(
        id: 'ds_premium_monthly',
        title: 'Monthly',
        description: '',
        price: '\$0.99',
        type: IapProductType.monthly,
      ));
      iap.emit(const IapPurchase(
        productId: 'ds_premium_monthly',
        status: IapPurchaseStatus.canceled,
      ));
      await _pumpEvents();

      expect(p.isPremium, isFalse);
      expect(p.isPurchasing, isFalse);
    });

    test('restore() delegates to the IAP service', () async {
      final iap = _FakeIap();
      final p = PremiumProvider(_FakeStore(), iap);
      await p.init();
      await p.restore();
      expect(iap.restoreCalls, 1);
    });
  });

  group('GoogleIapService.classifyProductId', () {
    test('maps the three configured SKUs', () {
      expect(GoogleIapService.classifyProductId('ds_premium_lifetime'),
          IapProductType.lifetime);
      expect(GoogleIapService.classifyProductId('ds_premium_monthly'),
          IapProductType.monthly);
      expect(GoogleIapService.classifyProductId('ds_premium_yearly'),
          IapProductType.yearly);
    });

    test('defaults unknown ids to yearly (defensive)', () {
      expect(GoogleIapService.classifyProductId('something_else'),
          IapProductType.yearly);
    });
  });
}
