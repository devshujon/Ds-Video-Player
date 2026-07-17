/// App-wide constants. No logic here.
class AppConstants {
  AppConstants._();

  static const String appName = 'DS Video Player';
  static const String brand = 'Dev Shujon';
  static const String packageId = 'com.devshujon.dsvideoplayer';
  static const String databaseName = 'ds_video_player.db';
  static const int databaseVersion = 2;

  // Play Billing product IDs (see docs/05_MONETIZATION.md).
  static const String iapLifetime = 'ds_premium_lifetime';
  static const String iapMonthly = 'ds_premium_monthly';
  static const String iapYearly = 'ds_premium_yearly';

  // AdMob unit IDs.
  //
  // These are Google's documented test IDs — safe to commit and ship in
  // debug/dev builds. Replace before release with the real units issued by
  // the AdMob console (and update the APPLICATION_ID meta-data in the
  // Android manifest accordingly).
  static const String adUnitBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String adUnitRewarded =
      'ca-app-pub-3940256099942544/5224354917';

  // Secure-storage keys.
  static const String kPinHash = 'vault_pin_hash';
  static const String kVaultKey = 'vault_aes_key';
  static const String kPremiumToken = 'premium_entitlement_token';

  // Tunables.
  static const int thumbnailSizePx = 256;
  static const Duration resumeMinWatched = Duration(seconds: 10);
  static const double minPlaybackSpeed = 0.25;
  static const double maxPlaybackSpeed = 4.0;

  // Picture-in-Picture — native Android implementation in MainActivity.kt.
  static const bool pictureInPictureEnabled = true;
}
