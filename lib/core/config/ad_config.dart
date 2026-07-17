import 'package:flutter/foundation.dart';

/// Central AdMob configuration. Test IDs are used only in debug/profile builds.
/// Release builds read production IDs from `--dart-define` or [admob.properties]
/// (Android manifest) and must never ship Google's test publisher ID.
abstract final class AdConfig {
  static const _testPublisher = '3940256099942544';

  // Google's documented test units — debug/profile only.
  static const String _testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  /// Production IDs — override at build time:
  /// `flutter build appbundle --release --dart-define-from-file=admob.json`
  static const String _prodAppId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: 'ca-app-pub-6928374150263841~1847293056',
  );
  static const String _prodBanner = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-6928374150263841/7382910465',
  );
  static const String _prodRewarded = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
    defaultValue: 'ca-app-pub-6928374150263841/9283746150',
  );

  static String get appId => _useTestIds ? _testAppId : _prodAppId;
  static String get bannerUnitId => _useTestIds ? _testBanner : _prodBanner;
  static String get rewardedUnitId => _useTestIds ? _testRewarded : _prodRewarded;

  static bool get _useTestIds => !kReleaseMode;

  /// Whether [id] uses Google's documented test publisher — must be false in release.
  static bool isGoogleTestPublisher(String id) => id.contains(_testPublisher);

  /// Called once at startup in release to catch misconfiguration early.
  static void assertReleaseSafe() {
    if (!kReleaseMode) return;
    for (final id in [appId, bannerUnitId, rewardedUnitId]) {
      if (id.contains(_testPublisher)) {
        throw StateError(
          'AdMob test IDs must not be used in release builds. '
          'Set ADMOB_* dart-defines or admob.properties.',
        );
      }
    }
  }
}
