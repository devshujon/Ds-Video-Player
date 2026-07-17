# DS Video Player — First Build & Platform Generation

This package now ships **the complete Android Kotlin-DSL Gradle scaffold**:
`build.gradle.kts`, `app/build.gradle.kts`, `settings.gradle.kts`,
`gradle.properties`, `gradle/wrapper/gradle-wrapper.properties`, the
audited `AndroidManifest.xml`, `MainActivity.kt` (extending
`FlutterFragmentActivity`), `proguard-rules.pro`, and the debug/profile
manifests.

Three things `flutter create` still needs to generate (binaries +
machine-specific paths cannot live in source):

1. **`android/gradlew` + `android/gradle/wrapper/gradle-wrapper.jar`** —
   Gradle wrapper executable + jar.
2. **`android/local.properties`** — your local `flutter.sdk` path.
3. **`android/app/src/main/res/{values,drawable,mipmap-*}/*`** — default
   launch theme + launcher icons.

## Step 1 — let `flutter create` fill in the gaps

```bash
cd ds_video_player
flutter create . --org com.devshujon --platforms=android
```

`flutter create` **only writes missing files** on an existing project —
the bundled `*.gradle.kts`, `AndroidManifest.xml`, `MainActivity.kt`, and
`proguard-rules.pro` are left untouched. It adds the three items above.

## Step 2 — verify nothing was overwritten (defensive)

```bash
grep -q "FlutterFragmentActivity" \
  android/app/src/main/kotlin/com/devshujon/ds_video_player/MainActivity.kt \
  || echo "WARNING: MainActivity is no longer FlutterFragmentActivity — restore it."
grep -q "READ_MEDIA_VIDEO" android/app/src/main/AndroidManifest.xml \
  || echo "WARNING: AndroidManifest was reset — restore from the package."
```

If either warns, restore those files from the unzipped source.

## Step 3 — build

```bash
flutter pub get
flutter analyze            # fix errors; infos / deprecation warnings are OK
flutter test               # 10 suites (1 stubbed pending sqflite_common_ffi)
flutter build apk --debug  # the first installable APK
# or: flutter run          # debug, on a physical device
```

## Configuration summary (already baked into the .kts files)

| Setting | Value | Why |
|---|---|---|
| `compileSdk` | `flutter.compileSdkVersion` | Tracks the Flutter SDK so contributors stay in lockstep |
| `targetSdk` | `flutter.targetSdkVersion` | Same as above |
| `minSdk` | `21` (hard) | media_kit / libmpv requirement; do not lower |
| `ndkVersion` | `flutter.ndkVersion` | Matches Flutter SDK's known-good NDK |
| AGP | `8.2.1` | Conservative, broadly compatible with Flutter 3.27+ |
| Gradle | `8.4` | Compatible with AGP 8.2.x |
| Kotlin | `1.9.22` | Stable, widely used by Flutter plugins |
| Java | `17` | Required by AGP 8.x |
| `MainActivity` | `FlutterFragmentActivity` | Required by `local_auth` (biometric) |
| `multiDexEnabled` | `true` | Headroom for the dependency graph |
| `minifyEnabled` | `false` (debug + release for now) | Flip to true for real release; `proguard-rules.pro` is ready |

## Picture-in-Picture (deliberately disabled — C2)

`floating` is intentionally absent from `pubspec.yaml`. PiP is gated by
`AppConstants.pictureInPictureEnabled = false`. To re-enable:

1. `flutter pub add floating`, note the resolved version.
2. Confirm its `enable(...)` API for that version.
3. Restore the implementation in
   `lib/features/player/presentation/screens/video_player_screen.dart`
   (`_enterPip` — there is a `TODO(pip)` marking the spot).
4. Flip the flag to `true`; the PiP button un-hides automatically.

The manifest already declares `supportsPictureInPicture` + the required
`configChanges`, so no manifest change is needed.
