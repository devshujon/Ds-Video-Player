# DS Video Player — Production Deployment

## Build prerequisites
- Flutter ≥ 3.22, Android SDK 34, NDK as required by `media_kit_libs_video`.
- `flutter pub get` → `flutter run` (debug) on a real device for media tests.

## Android configuration (already in `android/`)
- **Permissions:** `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_MEDIA_IMAGES` (Android 13+),
  `READ_EXTERNAL_STORAGE` (≤ API 32), `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK`, `INTERNET`, `USE_BIOMETRIC`.
- **Picture-in-Picture:** `android:supportsPictureInPicture="true"` +
  `android:configChanges` on the player activity.
- **Audio foreground service** declared for background playback.
- `largeHeap`, hardware acceleration, R8/ProGuard rules for media_kit & billing.

## Signing & release
1. Generate upload keystore; put secrets in `android/key.properties` (git-ignored).
2. `flutter build appbundle --release` → `.aab`.
3. `flutter build apk --split-per-abi` for sideload/QA.
4. Enable Play App Signing.

## Play Console rollout
1. Internal testing → fix → Closed (beta) → Open beta → Production staged 5%→20%→50%→100%.
2. Data Safety form: data stays on-device, no account, no tracking.
3. Declare ads, IAP; add privacy policy URL.
4. Pre-launch report device matrix; address ANR/crash before promote.

## Quality gates (block release if not met)
- Cold start TTI ≤ 1.5s mid-tier; crash-free sessions ≥ 99.5%.
- No jank > 16ms in list scroll (profile mode); memory stable over 30-min playback.
- `flutter analyze` clean; unit + widget tests green in CI.

## CI/CD (recommended)
- GitHub Actions: `flutter analyze` + `flutter test` on PR; tag → build signed `.aab` → Play internal track via `r0adkll/upload-google-play` with service account.

## Observability
- Crash/ANR + perf via Crashlytics (opt-in, anonymized). Remote config for pricing/feature flags & ad frequency caps.

## Rollback
- Halt staged rollout in Play Console; ship hotfix on a fast-tracked patch version. Keep last good `.aab` archived per release tag.
