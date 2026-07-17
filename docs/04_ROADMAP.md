# DS Video Player — Development Roadmap & Implementation Plan

## Phase 0 — Foundation (this PR)
- Project scaffold, clean architecture, DI, routing, theming (Light/Dark/AMOLED).
- SQLite schema + database layer + migrations.
- Media format registry, permission service, secure storage.
- Domain entities, repositories, use cases for media library.
- Providers: Theme, Premium, MediaLibrary, PhotoGallery, Settings, Player, Vault.
- Screens: splash, home (video/audio/photos/folders/more), player (video/audio),
  photo viewer, favorites, playlists, search, equalizer, vault, premium, settings.
- Ads + IAP integration points gated by `PremiumProvider`.

## Phase 1 — Core playback hardening (Sprint 1–2)
**1.1 — `feature/playback-hardening` (shipped):**
- ✅ Hardware decode default + user-toggle "Force software decode" (libmpv `hwdec=no`).
- ✅ Resume / continue-watching: periodic 5s persistence + end-of-playback flush;
  honors `Settings.resumePlayback`. "Continue watching" row in Videos tab.
- ✅ Gesture engine honors `Settings.gesturesEnabled` and `Settings.seekSeconds`;
  live HUD during horizontal seek-drag; double-tap L/R seek; lock; rotation lock.
- ✅ Subtitle pipeline: auto-detect sidecar `.srt/.ass/.ssa/.vtt`, file picker,
  on/off, delay (-5…+5s), font size (10–48pt). libmpv `sub-delay`/`sub-font-size`.
- ✅ Manual Picture-in-Picture entry via `floating` package.

**1.2 — deferred to follow-up branch:**
- Per-track audio / embedded subtitle selection UI (multi-track containers).
- Subtitle color / background / position styling.
- Auto-enter PiP on user-leave-hint (Android lifecycle callback).
- Background audio refactor: split audio engine to `just_audio` +
  `audio_service` for full lock-screen / Bluetooth controls (media_kit retains
  video). Foreground service is already declared in the manifest.
**1.2 — `feature/audio-service-split` (shipped):**
- ✅ Audio engine split off media_kit onto `just_audio` + `just_audio_background`.
  Every AudioSource carries an `audio_service.MediaItem` tag → lock-screen
  controls, notification, Bluetooth media keys, and wired-headset buttons
  work via the existing foreground service declared in the manifest.
- ✅ `AudioEngineProvider` is **app-scoped**: audio keeps playing across
  navigation. Foundation for the mini-player (Phase 5 polish).
- ✅ Queue via `ConcatenatingAudioSource`; gapless skip-next / skip-prev,
  shuffle + loop modes (off/one/all), speed 0.25–4×, periodic 5s resume
  persistence + completion flush.
- ✅ Video keeps `PlayerProvider` (media_kit / libmpv) untouched — full
  container/codec matrix, gestures, subtitles, HDR.

**Still ahead in Phase 1:**
- Hardware decode toggle, force-software fallback, rotation lock.
- Resume/continue-watching for video, gesture engine settings hook-up,
  subtitle pipeline (SRT/ASS/SSA/VTT load, delay, size/color/position),
  Picture-in-Picture.
- Per-track audio + embedded subtitle selection.

## Phase 2 — Library & management (Sprint 3–4)
**2.1 — `feature/library-incremental-scan` (shipped):**
- ✅ Incremental scanner with delta detection (`modified_at` + `size`):
  inserts new, updates changed, removes deleted, skips unchanged (zero writes).
- ✅ Batched persistence + cooperative `Future.delayed(Duration.zero)` yields
  so the UI thread stays responsive on large libraries.
- ✅ Streaming `MediaSource` interface; `PhotoManagerMediaSource` for prod,
  in-memory fake in tests. `LibraryIndexStore` abstraction for the same.
- ✅ `LibraryProvider` exposes `isScanning`, `scanProgress`, `newItemsFound`,
  `removedItems`, `updatedItems`, `lastSummary`, `recentlyAdded`.
- ✅ `LibraryScreen` with progress bar, Recently Added row, scan-complete banner.
- ✅ DB migration v1 → v2 adds `media_index` table.

**2.2 — follow-up branches:**
- Folder hide/pin, duplicate finder, storage cleaner, playlists reorder.
- Migrate Video/Audio tabs to read from `media_index` (deprecate v1 cache).
- Equalizer bound to actual audio session (Android `AudioEffect`).
**2.x — `feature/playlists-persistence` (shipped):**
- ✅ Playlists are SQLite-backed (`playlists` + `playlist_items`, schema v1):
  create / rename / delete, add items (de-duped), remove, drag-reorder.
- ✅ `PlaylistRepository` (interface + sqflite impl); `delete` relies on the
  `ON DELETE CASCADE` FK to drop items.
- ✅ `PlaylistsProvider` (app-scoped list) + route-scoped
  `PlaylistDetailProvider` (one playlist's ordered items).
- ✅ `PlaylistDetailScreen`: resolves item URIs against the scanned
  library, `ReorderableListView`, multi-select "Add items" sheet,
  per-item remove, "Play all" / play-from-item into `PlaybackArgs`.
  Unresolvable URIs render as "Unavailable" instead of breaking.
- ✅ `AppDatabase` gained an `overridePath` test seam → repository is
  tested against real in-memory SQLite via `sqflite_common_ffi`.

**Still ahead in Phase 2:**
- Fast incremental scanner, folder hide/pin, recently played row.
- Sort/filter, duplicate finder, storage cleaner.
**2.x — `feature/duplicate-finder` (shipped):**
- ✅ `DuplicateFinder`: two-pass detection — bucket by exact size (unique
  sizes skipped with zero I/O), then SHA-256 fingerprint of the first
  1 MiB of each same-size file. Fast on multi-GB videos; exact for files
  smaller than the sample window.
- ✅ `DuplicatesProvider` (route-scoped): scan with progress, groups
  sorted by reclaimable space, extras pre-selected (keep one), batch
  delete with disk reclaim totals.
- ✅ `DuplicateFinderScreen` + `/tools/duplicates` route + "Duplicate
  finder" entry in the More tab.

**Still ahead in Phase 2:**
- Fast incremental scanner, folder hide/pin, recently played row.
- Storage cleaner (large/old files), sort/filter.
**2.x — `feature/storage-cleaner` (shipped):**
- ✅ `StorageAnalyzer`: pure pass over the library — total bytes, per-type
  breakdown, largest-files sample (capped, sorted descending).
- ✅ `StorageCleanerProvider` (route-scoped): analyze, select, delete with
  in-place report adjustment (totals drop by exactly what was removed).
- ✅ `StorageCleanerScreen`: usage summary with per-type bars, largest-
  files checklist, bottom Delete bar + confirmation. `/tools/storage`
  route + More-tab entry.

**Still ahead in Phase 2:**
- Fast incremental scanner, folder hide/pin, recently played row.
- Sort/filter refinements.
- Equalizer bound to the audio session; bass boost, loudness, custom presets.

## Phase 3 — Privacy & monetization (Sprint 5)
**3.1 — `feature/iap-billing` (shipped):**
- ✅ `IapService` interface + `GoogleIapService` impl (in_app_purchase).
  Product loading for the three SKUs, purchase + restore flow,
  billing-event stream translated to plugin-agnostic `IapPurchase`.
- ✅ `PremiumProvider.init()` flow: cached Keystore token (offline grace)
  → connect billing → load products. Purchase events flip `isPremium` and
  rewrite the cached token. `restore()` re-queries past entitlements.
- ✅ Premium screen renders real products with localized prices (Play
  Billing-formatted), highlights lifetime as "BEST VALUE", surfaces
  billing-unavailable + load errors with retry.
- ✅ `unlock(token)` kept for non-Play paths (promo codes, debug).

**Still ahead in Phase 3:**
- Server-side receipt validation (see docs/05_MONETIZATION.md).
- AdMob banner + rewarded for the free tier, frequency caps, ad gating
  off the same `PremiumProvider`.
- Encrypted vault import/export (AES-GCM with the Keystore-derived key).
**3.2 — `feature/admob-ads` (shipped):**
- ✅ `AdService` boundary + `MobileAds.instance.initialize()` fire-and-forget
  at app startup (doesn't block cold start).
- ✅ `BannerAdView`: adaptive-friendly banner on library tabs, sits above
  the nav bar — never over the player. Ad load is **gated on
  `PremiumProvider.showAds`** in `initState`, so paying users never
  trigger an ad request at all; the widget is also reactive to a mid-
  session entitlement flip.
- ✅ `RewardedUnlockButton`: strictly user-initiated rewarded ad. The
  Equalizer's locked "Rock" preset now offers an opt-in
  "Watch ad to unlock for this session" path alongside the Upgrade CTA.
- ✅ Manifest uses Google's documented test AdMob app ID for dev builds;
  production IDs are swapped in pre-release.

**Still ahead in Phase 3:**
- Server-side receipt validation (see docs/05_MONETIZATION.md).
- Encrypted vault import/export (AES-GCM with the Keystore-derived key).
- Banner adaptive sizing across foldables / tablets.
**3.3 — `feature/encrypted-vault` (shipped):**
- ✅ `VaultCrypto`: chunked AES-GCM-256 (4 MiB chunks) so videos don't OOM.
  Per-chunk 12-byte nonce = random per-file prefix (8 B) || chunk_index (4 B)
  — no AES-GCM nonce ever reused under a key. Authenticated; tamper-evident.
- ✅ Blob layout: `magic("DSVB") | version | nonce_prefix | (len|cipher|tag)*`.
- ✅ `VaultRepository` (interface + sqflite impl) — owns blob lifecycle
  + `vault_items` row. Blobs live in `getApplicationSupportDirectory()/vault/`
  (not user-visible, not auto-backed-up).
- ✅ `VaultProvider` extended with `items`, `importFile`, `exportFile`,
  `delete`, progress + error state. Auto-loads on unlock; clears on lock.
- ✅ `VaultScreen` rewrite: encrypted file list with type icons + per-item
  Export/Delete menu, "Add file" FAB (file picker), import progress bar.

**Still ahead in Phase 3:**
- Server-side IAP receipt validation (see docs/05_MONETIZATION.md).
- Banner adaptive sizing on foldables / tablets.
- Vault blob backup/restore across reinstalls (export master key).

## Phase 4 — Streaming & cloud (Sprint 6–7)
**4.1 — `feature/streaming-urls` (shipped):**
- ✅ "Open network URL" screen: paste/clipboard a stream URL, live
  validation, recent-URL history (de-duped, capped, persisted), tap a
  recent to replay. Plays via the existing media_kit video player.
- ✅ `StreamUrl` validates HTTP/HTTPS/RTSP/RTMP(S); `RecentStreamsStore`
  persists history to shared_preferences; `StreamUrlProvider` is
  route-scoped. New `/stream/url` route + More-tab entry.

**Still ahead in Phase 4:**
- SMB / FTP / WebDAV via repository data sources.
- Chromecast / TV casting. Google Drive, Dropbox, OneDrive pickers.

## Phase 5 — AI & polish (Sprint 8)
**5.x — `feature/photo-date-grouping` (shipped):**
- ✅ `PhotoGrouper`: pure, generic date bucketing — Today / Yesterday /
  This week / Earlier this month / "Month Year", newest section first,
  newest item first within a section. Future timestamps fold into Today.
- ✅ `PhotoGalleryProvider` computes `sections` on album load; `PhotosTab`
  renders a sectioned `CustomScrollView` (sticky-style date headers +
  per-section grid) and still hands the viewer a flat album-ordered list
  so swipe spans the whole album.

**Still ahead in Phase 5:**
- Similar / duplicate image detection.
**5.1 — `feature/on-device-recommender` (shipped):**
- ✅ `Recommender`: pure on-device scoring —
  `base(playCount·w + completed·w + favorite·w) · 0.5^(age/halfLife)`.
  Recent, repeated, completed and favourited media rank highest; stale
  signals decay. No network, fully deterministic.
- ✅ Reads signals from tables the app already maintains —
  `playback_history` + `favorites` — via `RecommendationSource`
  (interface + sqlite impl). No new event-logging pipeline needed.
- ✅ `RecommendationsProvider` + "Suggested for you" screen (resolves
  scored URIs against the scanned library). New `/suggested` route +
  More-tab entry.

**Still ahead in Phase 5:**
- Smart grouping, similar / duplicate image detection.
- Floating player, video→audio mode, custom themes, slideshow transitions.

## Phase 6 — QA & launch (Sprint 9)
- Device matrix (low/high-end), perf budgets, crash-free ≥ 99.5%, Play Console rollout.

## Future update roadmap (post-1.0)
- 1.1 Chromecast + DLNA, gesture customization.
- 1.2 Cloud sync of favorites/playlists/history, Wear OS companion.
- 1.3 AI scene/chapter detection, auto-subtitle (on-device STT), per-app audio EQ.
- 1.4 Android TV / leanback UI, tablet two-pane, foldable support.
- 1.5 Plugin SDK for community decoders/themes.

## Step-by-step implementation order (engineering)
1. `flutter pub get` → run on Android device/emulator.
2. Configure Android: permissions, PiP, foreground service (`docs/08_DEPLOYMENT.md`).
3. Implement scanner data source against `photo_manager` + file walk; verify cache.
4. Bind `PlayerProvider` to `media_kit`; validate the full format matrix.
5. Layer history/favorites/playlists on the repositories.
6. Add ads/IAP keys; verify `PremiumProvider` gating.
7. Vault crypto + biometric; security review.
8. Streaming/cloud data sources behind existing repository interfaces.
9. Recommender SQL + UI row.
10. Test pass, profile, Play Console internal → closed → production.
