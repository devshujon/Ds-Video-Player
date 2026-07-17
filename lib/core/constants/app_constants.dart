import '../config/ad_config.dart';

/// App-wide constants. No logic here.
class AppConstants {
  AppConstants._();

  static const String appName = 'DS Video Player';
  static const String brand = 'Dev Shujon';
  static const String packageId = 'com.devshujon.ds_video_player';

  // Legal & support (publish docs/legal/ to GitHub Pages).
  static const String websiteUrl =
      'https://devshujon.github.io/Ds-Video-Player/';
  static const String privacyPolicyUrl =
      'https://devshujon.github.io/Ds-Video-Player/privacy';
  static const String termsUrl =
      'https://devshujon.github.io/Ds-Video-Player/terms';
  static const String supportEmail = 'ds.videoplayer.dev@gmail.com';

  static const String databaseName = 'ds_video_player.db';
  static const int databaseVersion = 2;

  // Play Billing product IDs (see docs/05_MONETIZATION.md).
  static const String iapLifetime = 'ds_premium_lifetime';
  static const String iapMonthly = 'ds_premium_monthly';
  static const String iapYearly = 'ds_premium_yearly';

  // Ad unit IDs — use [AdConfig] at runtime; these aliases remain for tests.
  static String get adUnitBanner => AdConfig.bannerUnitId;
  static String get adUnitRewarded => AdConfig.rewardedUnitId;

  // Secure-storage keys.
  static const String kPinHash = 'vault_pin_hash';
  static const String kVaultKey = 'vault_aes_key';
  static const String kPremiumToken = 'premium_entitlement_token';

  // Tunables.
  static const int thumbnailSizePx = 256;
  static const int thumbnailMaxMemoryEntries = 200;
  static const int thumbnailMaxDiskBytes = 200 * 1024 * 1024;
  static const Duration thumbnailMaxAge = Duration(days: 30);
  static const Duration resumeMinWatched = Duration(seconds: 10);
  static const double minPlaybackSpeed = 0.25;
  static const double maxPlaybackSpeed = 4.0;

  static const bool pictureInPictureEnabled = true;
}
