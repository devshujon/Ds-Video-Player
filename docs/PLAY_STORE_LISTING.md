# Google Play Store Listing — DS Video Player v1.0

## App identity

| Field | Value |
|-------|-------|
| App name | DS Video Player |
| Package | `com.devshujon.ds_video_player` |
| Version | 1.0.0 (3) |
| Category | Video Players & Editors |
| Content rating | Everyone (questionnaire required) |
| Target SDK | 36 (via Flutter) |
| Min SDK | 24 |

## Short description (80 chars max)

```
Fast local video player with gestures, PiP, subtitles & private vault.
```

## Full description

```
DS Video Player is a fast, modern video player for your local library.

▶ SMOOTH PLAYBACK
Hardware-accelerated decoding, gesture controls, pinch zoom, and multiple aspect ratios.

📺 ADVANCED FEATURES
• Picture-in-Picture
• Background playback with lock screen controls
• Subtitle support (SRT, VTT, ASS, embedded)
• Resume from last position
• Bluetooth & headset controls

📁 SMART LIBRARY
Browse videos, folders, audio, downloads, favorites, and hidden items. Grid or list view with fast thumbnails.

🔒 PRIVATE VAULT
Encrypt sensitive files behind a PIN or biometric lock.

🎨 PREMIUM EXPERIENCE
Dark, AMOLED, and light themes. No ads with Premium.

DS Video Player by Dev Shujon — your media, on your device.
```

## Keywords

video player, local player, MX player alternative, subtitle, PiP, gesture, vault, media library

## URLs

| Item | URL |
|------|-----|
| Privacy policy | https://devshujon.github.io/Ds-Video-Player/privacy |
| Terms | https://devshujon.github.io/Ds-Video-Player/terms |
| Website | https://devshujon.github.io/Ds-Video-Player/ |
| Support email | ds.videoplayer.dev@gmail.com |

## Permissions justification (Play Console)

| Permission | Why |
|------------|-----|
| READ_MEDIA_VIDEO/AUDIO/IMAGES | Local library scanning (scoped storage) |
| READ_EXTERNAL_STORAGE (≤API 32) | Legacy device support |
| INTERNET | Streaming URLs, ads, IAP |
| POST_NOTIFICATIONS | Background playback controls |
| FOREGROUND_SERVICE_MEDIA_PLAYBACK | Video background audio |
| USE_BIOMETRIC | Vault unlock |
| BILLING | Premium purchases |

## Assets checklist

| Asset | Size | Status |
|-------|------|--------|
| Adaptive icon | 512×512 foreground + background | ☐ Verify in `android/app/src/main/res/` |
| Feature graphic | 1024×500 | ☐ Create for Play Console |
| Phone screenshots | ≥ 2, 16:9 or 9:16 | ☐ Capture from device |
| 7-inch tablet screenshots | Optional | ☐ |
| 10-inch tablet screenshots | Optional | ☐ |

## Release build commands

```bash
# Configure secrets (not in repo):
cp android/key.properties.example android/key.properties
cp admob.json.example admob.json

flutter build appbundle --release --dart-define-from-file=admob.json
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console → Internal testing first.
