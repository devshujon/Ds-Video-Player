import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/services/premium_token_store.dart';
import '../../data/iap_product.dart';
import '../../data/iap_service.dart';

/// Single source of truth for entitlement. Every ad placement and premium
/// gate reads [isPremium].
///
/// Entitlement flow:
///   1. [restoreFromCache] — read the Keystore-cached token at startup.
///      Premium is granted offline if the cache says so (grace window).
///   2. [init] subscribes to the IAP purchase stream. New purchases /
///      restores write a fresh token to Keystore and flip [isPremium].
///   3. Server-side receipt validation against Google Play's Purchases
///      API is the production hardening step (`docs/05_MONETIZATION.md`).
class PremiumProvider extends ChangeNotifier {
  PremiumProvider(this._secure, this._iap);

  final PremiumTokenStore _secure;
  final IapService _iap;

  bool _isPremium = false;
  bool isLoadingProducts = false;
  bool isPurchasing = false;
  bool isBillingAvailable = false;
  String? errorText;
  List<IapProduct> products = const [];

  StreamSubscription<IapPurchase>? _purchaseSub;

  bool get isPremium => _isPremium;
  bool get showAds => !_isPremium;

  /// Bootstrap: cached entitlement first (synchronous-feeling premium),
  /// then connect billing and load products if available.
  Future<void> init() async {
    await restoreFromCache();
    isBillingAvailable = await _iap.isAvailable();
    if (isBillingAvailable) {
      _purchaseSub = _iap.purchaseStream.listen(_onPurchaseEvent);
      await loadProducts();
    } else {
      notifyListeners();
    }
  }

  Future<void> restoreFromCache() async {
    final token = await _secure.readPremiumToken();
    _isPremium = token != null && token.isNotEmpty;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    if (!isBillingAvailable) return;
    isLoadingProducts = true;
    errorText = null;
    notifyListeners();
    try {
      products = await _iap.loadProducts();
    } catch (e) {
      errorText = 'Could not load plans: $e';
    } finally {
      isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// Kicks off the platform purchase flow. The actual entitlement flip
  /// happens asynchronously when the billing event arrives on
  /// [IapService.purchaseStream] — see [_onPurchaseEvent].
  Future<void> purchase(IapProduct product) async {
    if (isPurchasing) return;
    isPurchasing = true;
    errorText = null;
    notifyListeners();
    try {
      await _iap.purchase(product);
    } catch (e) {
      errorText = 'Purchase failed: $e';
      isPurchasing = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    errorText = null;
    notifyListeners();
    try {
      await _iap.restore();
    } catch (e) {
      errorText = 'Restore failed: $e';
      notifyListeners();
    }
  }

  /// Public path for tests / non-Play flows (debug menu, promo codes).
  /// Marks the user premium and caches the verified token in Keystore.
  Future<void> unlock(String verifiedToken) async {
    await _secure.writePremiumToken(verifiedToken);
    _isPremium = true;
    notifyListeners();
  }

  bool isLocked(PremiumFeature _) => !_isPremium;

  Future<void> _onPurchaseEvent(IapPurchase event) async {
    switch (event.status) {
      case IapPurchaseStatus.success:
      case IapPurchaseStatus.restored:
        final token = event.verificationToken;
        if (token != null && token.isNotEmpty) {
          await _secure.writePremiumToken(token);
          _isPremium = true;
        }
        isPurchasing = false;
      case IapPurchaseStatus.error:
        errorText = event.error ?? 'Billing error';
        isPurchasing = false;
      case IapPurchaseStatus.canceled:
        isPurchasing = false;
      case IapPurchaseStatus.pending:
        // Stay in isPurchasing=true while Play resolves.
        break;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _iap.dispose();
    super.dispose();
  }
}

enum PremiumFeature {
  removeAds,
  amoledTheme,
  customThemes,
  customEqPresets,
  cloudSync,
  floatingPlayer,
  unlimitedVault,
}
