import 'package:ds_video_player/core/config/ad_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configured production default IDs are not Google test publisher', () {
    const productionDefaults = [
      'ca-app-pub-6928374150263841~1847293056',
      'ca-app-pub-6928374150263841/7382910465',
      'ca-app-pub-6928374150263841/9283746150',
    ];
    for (final id in productionDefaults) {
      expect(AdConfig.isGoogleTestPublisher(id), isFalse);
      expect(id, startsWith('ca-app-pub-'));
    }
  });

  test('detects Google test publisher IDs', () {
    expect(
      AdConfig.isGoogleTestPublisher('ca-app-pub-3940256099942544/6300978111'),
      isTrue,
    );
  });
}
