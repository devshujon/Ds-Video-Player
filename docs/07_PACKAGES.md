# DS Video Player — Required Flutter Packages

| Package | Why |
|---|---|
| `provider` | App + route state (ChangeNotifier) — required state mgmt |
| `get_it` | DI / service locator for use cases & repositories |
| `sqflite`, `path` | SQLite database + migrations |
| `path_provider`, `shared_preferences` | App dirs, user preferences |
| `media_kit`, `media_kit_video`, `media_kit_libs_video` | libmpv engine — VLC-class container/codec coverage, HW decode + SW fallback, HDR, 4K/8K, subtitles, speed 0.25–4x |
| `just_audio`, `just_audio_background`, `audio_service` | Background audio, media notification, lock-screen controls |
| `photo_manager` | Device MediaStore scan (videos + images), albums, thumbnails |
| `photo_view` | Pinch-zoom photo viewer / slideshow |
| `permission_handler` | Android 13+ granular media permissions |
| `screen_brightness`, `flutter_volume_controller` | Player gesture brightness/volume |
| `wakelock_plus` | Keep screen on during video only |
| `flutter_secure_storage` | Keystore-backed PIN hash, vault key, premium token |
| `local_auth` | Fingerprint / biometric for vault |
| `crypto` | AES/key derivation for vault & entitlement token |
| `google_mobile_ads` | Banner + rewarded (free tier) |
| `in_app_purchase` | Lifetime + subscription premium |
| `google_fonts`, `shimmer`, `cached_network_image`, `flutter_svg` | Premium MD3 UI, skeleton loaders, network thumbs, vector assets |
| `intl`, `equatable`, `collection` | Formatting, value equality, list utils |
| `flutter_lints` (dev) | Static analysis / code quality |

## Format/codec coverage (via media_kit / libmpv)
**Containers:** MP4, MKV, AVI, MOV, FLV, WMV, WebM, TS, MTS, M2TS, MPG, MPEG, VOB, ASF, RM, RMVB, 3GP, M4V, OGV.
**Audio containers:** MP3, AAC, WAV, FLAC, OGG, OPUS, M4A, WMA, AC3, DTS, AMR, AIFF, MIDI, APE.
**Video codecs:** H.264, H.265/HEVC, VP8, VP9, AV1, MPEG-2, MPEG-4, Xvid, DivX.
**Audio codecs:** AAC, MP3, FLAC, AC3, EAC3, DTS, Dolby, Opus.
**Images:** JPG, JPEG, PNG, WEBP, GIF, BMP, TIFF, HEIC, SVG.

Strategy: try hardware decoder → on failure/unsupported, libmpv software decode automatically (`--hwdec=auto-safe`). Corrupt files: demux best-effort, skip bad packets, surface a friendly error instead of crashing.

> Cloud/streaming SDKs (Chromecast, Drive/Dropbox/OneDrive, SMB/FTP/WebDAV) are added per `docs/04_ROADMAP.md` Phase 4 behind existing repository interfaces — not bundled in Phase 0 to keep startup/APK lean.
