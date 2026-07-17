# DS Video Player

Premium Android offline media player by **Dev Shujon** — built to compete with MX Player, VLC, and XPlayer.

## Highlights

- **media_kit (libmpv)** — hardware-accelerated playback, broad codec support, external subtitles
- **Fast MediaStore scanner** — progressive library loading, no filesystem walks, thumbnail disk cache
- **Premium UI** — glassmorphism cards, Continue Watching hero, grid/list toggle, shimmer placeholders
- **Advanced gestures** — brightness, volume, seek, double-tap, pinch zoom, long-press 2× speed
- **Player controls** — sleep timer, aspect ratio modes, speed 0.25×–4× (incl. 1.75×), lock, resume
- **Clean architecture** — feature modules, Riverpod-ready (`ProviderScope`), GetIt DI, SQLite cache

## Run

```bash
flutter pub get
flutter run
```

## Verify

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Package

`com.devshujon.ds_video_player`
