# DS Video Player — Architecture

**Brand:** Dev Shujon · **Framework:** Flutter · **Pattern:** Clean Architecture (feature-first) · **State:** Provider · **DB:** SQLite

---

## 1. Architectural principles

- **Clean Architecture, 3 layers per feature:** `presentation → domain → data`. Dependencies point inward only. The `domain` layer has zero Flutter/plugin imports.
- **Feature-first:** every feature is a self-contained vertical slice. A feature never imports another feature's **`data` layer**; cross-feature data contracts live in `core` or are reached through a `domain` repository interface.
- **Cross-cutting presentation is allowed and expected** (reconciled with the
  actual code during build-stabilization): a small set of app-scoped
  providers and shared widgets are deliberately treated as shared UI
  infrastructure and may be imported by any feature:
  - **App-scoped providers** (created once in `app.dart`): `ThemeController`,
    `PremiumProvider`, `SettingsProvider`, `MediaLibraryProvider`,
    `PhotoGalleryProvider`, `AudioEngineProvider`, `LibraryProvider`,
    `PlaylistsProvider`. Reading these across features is normal Provider
    usage — they exist at the app root precisely to be globally available.
  - **Shared widgets**: `MediaTile`, `BannerAdView`, `RewardedUnlockButton`.
    These are candidates to migrate into `lib/core/widgets/` so the
    dependency direction is explicit; until then, treat them as shared.
  - **Domain entities** (`MediaItem`, `PlaybackArgs`, …) are free to cross
    feature boundaries — that is the intended `domain` contract path.
  Route-scoped providers and a feature's `screens/` remain private to that
  feature. The verified import graph is acyclic (no circular dependencies).
- **Provider + ChangeNotifier** for UI state; **get_it** for dependency injection (constructing use cases/repositories, not for UI state).
- **Result type** instead of throwing across layers: `Result<T> = Success<T> | FailureResult(Failure)`.
- **Offline-first:** the device library is the source of truth; SQLite caches metadata, history, favorites, playlists, settings.

```
Widget ──reads──> Provider (ChangeNotifier) ──calls──> UseCase ──> Repository (interface)
                                                                      │
                                              ┌───────────────────────┴───────────────────────┐
                                       RemoteDataSource                                  LocalDataSource
                                  (media_kit / network / cloud)                      (sqflite / photo_manager / fs)
```

## 2. Complete folder structure

```
ds_video_player/
├── android/                         # Native config, permissions, PiP, gradle
├── assets/{images,icons}/
├── docs/                            # This documentation set
├── test/                            # Unit + widget tests
└── lib/
    ├── main.dart                    # Bootstrap: DI, media_kit, error zone
    ├── app/
    │   ├── app.dart                 # MaterialApp + MultiProvider root
    │   ├── di/service_locator.dart  # get_it registrations
    │   └── router/
    │       ├── app_router.dart      # onGenerateRoute
    │       └── route_names.dart
    ├── core/
    │   ├── constants/               # app_constants, media_formats
    │   ├── theme/                   # app_colors, app_theme, theme_controller
    │   ├── error/failures.dart
    │   ├── utils/                   # result, formatters
    │   ├── services/                # permissions, secure_storage
    │   └── database/                # app_database, schema, migrations
    └── features/
        ├── splash/presentation/
        ├── media_library/{data,domain,presentation}/
        ├── player/{domain,presentation}/
        ├── photos/{data,domain,presentation}/
        ├── favorites/presentation/
        ├── playlists/{domain,presentation}/
        ├── search/presentation/
        ├── equalizer/presentation/
        ├── vault/{domain,presentation}/
        ├── premium/{domain,presentation}/
        └── settings/presentation/
```

Each `data/` has `datasources/`, `models/`, `repositories/`; each `domain/` has `entities/`, `repositories/`, `usecases/`; each `presentation/` has `providers/`, `screens/`, `widgets/`.

## 3. State management architecture

| Provider | Scope | Responsibility |
|---|---|---|
| `ThemeController` | App | Light / Dark / AMOLED / accent, persisted to prefs |
| `PremiumProvider` | App | Entitlement (IAP), gates ad display & premium features |
| `MediaLibraryProvider` | App | Scan + cache videos/audio/folders, sort/filter, history, favorites |
| `PhotoGalleryProvider` | App | Albums, images, sort, hidden, favorites |
| `PlayerProvider` | Route | Wraps media_kit `Player`; speed, subtitles, gestures, resume |
| `AudioPlayerProvider` | App | Background audio queue (audio_service) |
| `SettingsProvider` | App | All user preferences |
| `VaultProvider` | Route | Encrypted private vault, biometric/PIN gate |

App-scoped providers are created in `app.dart` via `MultiProvider`; route-scoped providers are created with `ChangeNotifierProvider` at the screen. Selectors (`context.select`) are used in lists to avoid rebuilds.

## 4. Widget tree (high level)

```
DSVideoPlayerApp
└── MultiProvider [Theme, Premium, MediaLibrary, PhotoGallery, AudioPlayer, Settings]
    └── MaterialApp.router
        ├── SplashScreen ──(perm + first scan)──> HomeScreen
        ├── HomeScreen
        │   └── Scaffold
        │       ├── Search action ─> SearchScreen
        │       └── IndexedStack(NavigationBar)
        │           ├── VideoTab     (grid/list + folder filter)
        │           ├── AudioTab     (tracks/albums/artists)
        │           ├── PhotosTab    (albums + grid, photo_view)
        │           ├── FoldersScreen(tree, hidden toggle)
        │           └── MoreTab      (Favorites, Playlists, Vault, Settings, Premium)
        ├── VideoPlayerScreen  → Video + GestureOverlay + ControlsBar + SubtitleSheet
        ├── AudioPlayerScreen  → NowPlaying + Queue + MiniPlayer (persistent)
        ├── EqualizerScreen, VaultScreen, PremiumScreen, SettingsScreen
```

## 5. Performance strategy

- **Startup:** deferred DI; splash renders immediately; media scan runs after first frame on a background isolate-friendly path; cached metadata shown before rescan completes.
- **Lists:** `ListView/GridView.builder`, `cacheExtent` tuned, thumbnails via `photo_manager` byte cache + `cached_network_image` style memory cache, `const` widgets, `RepaintBoundary` on tiles.
- **Memory:** thumbnail size capped (256px), `Player` disposed on route pop, image cache size bounded.
- **Battery:** `WakelockPlus` only while a video plays; audio uses foreground service; scans throttled & debounced; no polling.
- **Codec/decode:** media_kit (libmpv) with hardware decoding enabled and automatic software fallback — covers the full container/codec matrix in `docs/07_PACKAGES.md`.
