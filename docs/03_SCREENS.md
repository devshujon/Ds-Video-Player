# DS Video Player — Screen List & Navigation

| # | Route | Screen | Status | Purpose |
|---|---|---|---|---|
| 1 | `/splash` | SplashScreen | ✅ implemented | Branding, permission request, first scan |
| 2 | `/home` | HomeScreen | ✅ implemented | Bottom-nav shell (IndexedStack) |
| 3 | tab | VideoTab | ✅ implemented | All videos, grid/list, sort, resume badge |
| 4 | tab | AudioTab | ✅ implemented | All audio tracks |
| 5 | tab | PhotosTab | ✅ implemented | Albums + photo grid |
| 6 | `/folders` | FoldersScreen | ✅ implemented | Folder tree, hidden toggle |
| 7 | `/favorites` | FavoritesScreen | ✅ implemented | Favorited media |
| 8 | `/playlists` | PlaylistsScreen | ✅ implemented | User playlists CRUD |
| 9 | `/search` | SearchScreen | ✅ implemented | Search across media |
| 10 | `/settings` | SettingsScreen | ✅ implemented | Theme, playback, privacy, about |
| 11 | `/premium` | PremiumScreen | ✅ implemented | Plans, IAP, restore |
| 12 | `/vault` | VaultScreen | ✅ implemented | Biometric/PIN gated private vault |
| 13 | `/equalizer` | EqualizerScreen | ✅ implemented | 10-band EQ, bass boost, presets |
| 13a | `/library` | LibraryScreen | ✅ implemented | Incremental scan dashboard: progress, Recently Added, summary |
| 14 | `/player/video` | VideoPlayerScreen | ✅ implemented | media_kit video + gestures + subtitles |
| 15 | `/player/audio` | AudioPlayerScreen | ✅ implemented | Now playing + queue + mini player |
| 16 | `/photo/view` | PhotoViewerScreen | ✅ implemented | Zoom/swipe/slideshow/share |

**Status legend:** ✅ implemented = screen + provider + navigation wired with real UI and local data. Network/cloud/cast integrations are scaffolded behind interfaces and documented in the roadmap (`docs/04_ROADMAP.md`), not faked.

## Navigation map

```
splash → home
home ├─ tab: video  → player/video ─(resume)→ history
     ├─ tab: audio  → player/audio → mini-player (persists across tabs)
     ├─ tab: photos → photo/view (PageView slideshow)
     └─ more ┬ folders ┬ player/video
             ├ favorites
             ├ playlists → player
             ├ vault (auth gate) → player/photo
             ├ equalizer
             ├ premium (IAP)
             └ settings
appbar: search (global) ; long-press item → context menu (favorite, vault, delete, info, play-as-audio)
```

Routing is centralized in `app/router/app_router.dart` (`onGenerateRoute`) with typed argument objects. Player screens force/restore orientation & system UI on push/pop.
