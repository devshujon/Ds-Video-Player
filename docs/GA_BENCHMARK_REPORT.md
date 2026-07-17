# Performance Benchmark Report — DS Video Player v1.0 GA

**Build:** 1.0.0+3  
**Engine:** media_kit (libmpv)  
**Date:** July 2026

## Methodology

| Metric | Environment | Tool |
|--------|-------------|------|
| Cold start (init) | CI / unit test | `test/startup_benchmark_test.dart` |
| Cold start (full) | Physical device required | Android Studio Profiler |
| Memory | Physical device required | Android Studio Memory Profiler |
| Frame pacing | Physical device required | Flutter DevTools Performance |
| APK/AAB size | CI release build | `ls -lh` on artifacts |

> CI cannot substitute for on-device profiling. Values marked **(device)** must be collected before production release.

## CI measurements

| Metric | Result | Target | Status |
|--------|--------|--------|--------|
| SQLite in-memory open | < 700 ms | < 700 ms | ✅ Pass |
| Release APK size | ~100 MB | < 120 MB | ✅ Pass |
| Release AAB size | ~79 MB | < 100 MB | ✅ Pass |
| `flutter analyze` | 0 issues | 0 | ✅ Pass |
| `flutter test` | 85+ pass | All pass | ✅ Pass |

## Device measurements (template)

Fill in after physical QA session:

| Metric | Device A | Device B | Target |
|--------|----------|----------|--------|
| Cold start (tap → home) **(device)** | ___ ms | ___ ms | < 700 ms |
| Warm start **(device)** | ___ ms | ___ ms | < 400 ms |
| Idle memory (library) **(device)** | ___ MB | ___ MB | < 200 MB |
| Peak memory (playback) **(device)** | ___ MB | ___ MB | < 400 MB |
| Library scroll FPS **(device)** | ___ fps | ___ fps | ≥ 58 fps |
| Playback start latency **(device)** | ___ ms | ___ ms | < 500 ms |
| Seek latency **(device)** | ___ ms | ___ ms | < 300 ms |
| Scan 5000 videos **(device)** | ___ s | ___ s | < 120 s |

## Battery summary

| Optimization | Impact |
|--------------|--------|
| Foreground service only during video playback | High |
| Combined 8s persist timer (was 3 timers) | Medium |
| Event-driven MediaSession (no 1s poll) | Medium |
| Thumbnail LRU + disk cap | Medium |
| Deferred IAP/AdMob init | Low |

## Recommendations

1. Profile cold start on a mid-range API 33 device before production.
2. Run Memory Profiler with 5,000+ video library.
3. Verify frame pacing during pinch-zoom seek in 4K content.
