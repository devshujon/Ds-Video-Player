import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ds_video_player/features/player/data/services/playback_state_store.dart';
import 'package:ds_video_player/features/player/domain/entities/playback_state.dart';
import 'package:ds_video_player/features/player/domain/entities/player_enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PlaybackStateStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = PlaybackStateStore(prefs);
  });

  test('round-trips full playback state per URI', () async {
    const uri = '/storage/emulated/0/Movies/demo.mp4';
    const state = PlaybackState(
      positionMs: 125000,
      subtitleUri: '/storage/emulated/0/Movies/demo.srt',
      subtitleEnabled: true,
      audioTrackId: 'audio-1',
      speed: 1.5,
      aspectMode: AspectRatioMode.ratio16x9,
      videoScale: 1.2,
      subtitleDelaySec: 0.5,
      subtitleFontScale: 1.1,
      subtitleColorArgb: 0xFFFFFF00,
      subtitleBackgroundOpacity: 0.6,
      subtitleOutline: false,
    );

    await store.save(uri, state);
    final loaded = await store.load(uri);

    expect(loaded, isNotNull);
    expect(loaded!.positionMs, 125000);
    expect(loaded.subtitleUri, endsWith('demo.srt'));
    expect(loaded.speed, 1.5);
    expect(loaded.aspectMode, AspectRatioMode.ratio16x9);
    expect(loaded.subtitleColorArgb, 0xFFFFFF00);
    expect(loaded.subtitleOutline, isFalse);
  });

  test('clear removes stored state', () async {
    const uri = '/storage/a.mp4';
    await store.save(uri, const PlaybackState(positionMs: 1000));
    await store.clear(uri);
    expect(await store.load(uri), isNull);
  });
}
