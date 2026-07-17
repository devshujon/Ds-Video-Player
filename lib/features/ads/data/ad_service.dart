import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Thin boundary around the AdMob SDK. Centralises initialisation and the
/// ad-unit IDs so callers don't reach into `google_mobile_ads` directly.
///
/// The SDK's own singleton ([MobileAds.instance]) is the real worker; this
/// class just packages the calls and gives us a seam for tests and for a
/// future remote-config-driven ad strategy.
class AdService {
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Idempotent. Fire-and-forget at app startup — banners that race the
  /// init complete just fail-and-hide on first attempt.
  Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }
}
