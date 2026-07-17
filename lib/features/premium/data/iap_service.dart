import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/constants/app_constants.dart';
import 'iap_product.dart';

enum IapPurchaseStatus { pending, success, restored, error, canceled }

/// One purchase-stream event translated out of `in_app_purchase` types so
/// the presentation layer has zero dependency on the plugin.
class IapPurchase {
  const IapPurchase({
    required this.productId,
    required this.status,
    this.verificationToken,
    this.error,
  });

  final String productId;
  final IapPurchaseStatus status;

  /// Locally-packed verification payload (purchase id + product id + Play
  /// signed verification string + tamper-evident hash). Cached in Keystore
  /// by [PremiumProvider]. Server-side validation against Google's
  /// Purchases API is the production hardening step — see
  /// docs/05_MONETIZATION.md.
  final String? verificationToken;
  final String? error;
}

/// Billing boundary. Implemented for Google Play here; an iOS impl would
/// plug in behind the same interface.
abstract interface class IapService {
  /// Whether billing is connected and usable on this device.
  /// Idempotent — safe to call any number of times.
  Future<bool> isAvailable();

  /// Loads product details (price, title) for the SKUs in [AppConstants].
  Future<List<IapProduct>> loadProducts();

  /// Launches the platform purchase dialog. Result is delivered via
  /// [purchaseStream] (so callers can react to async billing events).
  Future<void> purchase(IapProduct product);

  /// Re-asks the platform for past entitlements. Each is delivered as a
  /// [IapPurchaseStatus.restored] event on [purchaseStream].
  Future<void> restore();

  /// Single broadcast stream of every billing-related event for the
  /// app's lifetime.
  Stream<IapPurchase> get purchaseStream;

  Future<void> dispose();
}

class GoogleIapService implements IapService {
  GoogleIapService();

  final InAppPurchase _iap = InAppPurchase.instance;
  final StreamController<IapPurchase> _events =
      StreamController<IapPurchase>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _streamSub;
  Map<String, ProductDetails> _productCache = const {};

  @override
  Stream<IapPurchase> get purchaseStream => _events.stream;

  @override
  Future<bool> isAvailable() async {
    final ok = await _iap.isAvailable();
    if (ok) {
      _streamSub ??= _iap.purchaseStream.listen(
        _handlePurchases,
        onError: (Object e, StackTrace _) {
          _events.add(IapPurchase(
            productId: '',
            status: IapPurchaseStatus.error,
            error: e.toString(),
          ));
        },
      );
    }
    return ok;
  }

  @override
  Future<List<IapProduct>> loadProducts() async {
    final response = await _iap.queryProductDetails(const {
      AppConstants.iapLifetime,
      AppConstants.iapMonthly,
      AppConstants.iapYearly,
    });
    _productCache = {for (final p in response.productDetails) p.id: p};
    return response.productDetails.map(_mapProduct).toList(growable: false);
  }

  IapProduct _mapProduct(ProductDetails d) {
    return IapProduct(
      id: d.id,
      title: d.title,
      description: d.description,
      price: d.price,
      rawPrice: d.rawPrice.toString(),
      currencyCode: d.currencyCode,
      type: classifyProductId(d.id),
    );
  }

  /// Visible for testing — maps SKU id → product type.
  static IapProductType classifyProductId(String id) {
    if (id == AppConstants.iapLifetime) return IapProductType.lifetime;
    if (id == AppConstants.iapMonthly) return IapProductType.monthly;
    return IapProductType.yearly;
  }

  @override
  Future<void> purchase(IapProduct product) async {
    final pd = _productCache[product.id];
    if (pd == null) {
      throw StateError('Product not loaded: ${product.id}');
    }
    final param = PurchaseParam(productDetails: pd);
    // All three SKUs are non-consumable from the plugin's standpoint:
    // lifetime is one-shot, subs are treated as non-consumable on Play.
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _events.add(IapPurchase(
            productId: p.productID,
            status: IapPurchaseStatus.pending,
          ));
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final token = packVerification(p);
          _events.add(IapPurchase(
            productId: p.productID,
            status: p.status == PurchaseStatus.restored
                ? IapPurchaseStatus.restored
                : IapPurchaseStatus.success,
            verificationToken: token,
          ));
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
        case PurchaseStatus.error:
          _events.add(IapPurchase(
            productId: p.productID,
            status: IapPurchaseStatus.error,
            error: p.error?.message ?? 'Unknown billing error',
          ));
        case PurchaseStatus.canceled:
          _events.add(IapPurchase(
            productId: p.productID,
            status: IapPurchaseStatus.canceled,
          ));
      }
    }
  }

  /// Packs the platform-signed verification string together with the SKU
  /// id and a SHA-256 hash so the cached entitlement is tamper-evident at
  /// rest. Server-side validation against Google Play's Purchases API is
  /// the production hardening step (`docs/05_MONETIZATION.md`).
  static String packVerification(PurchaseDetails p) {
    final payload = [
      p.productID,
      p.purchaseID ?? '',
      p.verificationData.serverVerificationData,
    ].join('|');
    final hash = sha256.convert(utf8.encode(payload)).toString();
    return '$payload|$hash';
  }

  @override
  Future<void> dispose() async {
    await _streamSub?.cancel();
    await _events.close();
  }
}
