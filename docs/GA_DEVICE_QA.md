# Device QA Checklist — DS Video Player v1.0

Use this checklist on physical devices running Android 10 (API 29) through Android 15 (API 35).

## Devices

| Category | Devices to test | Pass |
|----------|-----------------|------|
| Phone (small) | 5.5" 720p, API 29 | ☐ |
| Phone (mid) | 6.5" 1080p, API 33 | ☐ |
| Phone (flagship) | 6.7" 1440p, API 35 | ☐ |
| Tablet | 10" landscape, API 31 | ☐ |
| Foldable | Split inner/outer, API 34 | ☐ |

## Orientation & display

| Test | Pass |
|------|------|
| Portrait library browsing | ☐ |
| Landscape video playback | ☐ |
| Rotation lock in player | ☐ |
| Split-screen (50/50 with Chrome) | ☐ |
| Foldable cover → inner display resume | ☐ |
| Large font (200%) — no clipped controls | ☐ |
| TalkBack — player controls announced | ☐ |

## Permissions

| Test | Pass |
|------|------|
| Grant media on first launch | ☐ |
| Deny media — empty library, no crash | ☐ |
| Deny notifications — background audio still works | ☐ |
| Re-grant from system settings | ☐ |

## Playback

| Test | Pass |
|------|------|
| Local MP4/MKV instant start | ☐ |
| Resume position after reopen | ☐ |
| Seek smooth, no freeze | ☐ |
| Subtitle SRT/VTT/ASS load | ☐ |
| Hardware/software decoder switch | ☐ |
| PiP enter/exit/restore | ☐ |
| Background audio + notification controls | ☐ |
| Bluetooth headset play/pause/skip | ☐ |
| Wired headset unplug pauses | ☐ |
| Phone call interrupts and resumes | ☐ |

## Library

| Test | Pass |
|------|------|
| First scan 1000+ videos completes | ☐ |
| Scroll 5000+ library at 60fps | ☐ |
| Thumbnails load without OOM | ☐ |
| Search returns results < 300ms | ☐ |
| Favorites persist after restart | ☐ |

## Storage stress

| Test | Pass |
|------|------|
| Device < 500 MB free — graceful errors | ☐ |
| Thumbnail cache stays under 200 MB | ☐ |
| Corrupt DB — app recreates and rescans | ☐ |

## Premium & ads

| Test | Pass |
|------|------|
| Free tier shows banner on library only | ☐ |
| Premium hides all ads | ☐ |
| IAP purchase + restore | ☐ |
| Release build has no test AdMob IDs | ☐ |

## Sign-off

| Role | Name | Date |
|------|------|------|
| Developer | | |
| QA | | |
