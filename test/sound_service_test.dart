import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sound mapping reuses the existing assets', () {
    final service = SoundService.instance;

    expect(service.assetFor(AppSound.message), 'sounds/messages.wav');
    expect(service.assetFor(AppSound.match), 'sounds/newmatch.wav');
    expect(service.assetFor(AppSound.success), 'sounds/splash.wav');
    expect(service.assetFor(AppSound.undo), 'sounds/splash.wav');
  });

  test('sound volumes are bounded and distinct', () {
    final service = SoundService.instance;

    for (final sound in AppSound.values) {
      expect(service.volumeFor(sound), greaterThan(0));
      expect(service.volumeFor(sound), lessThanOrEqualTo(1));
    }
    expect(
      service.volumeFor(AppSound.match),
      greaterThan(service.volumeFor(AppSound.success)),
    );
  });

  test('every mapped asset exists in the bundle', () async {
    for (final sound in AppSound.values) {
      final asset = SoundService.instance.assetFor(sound);
      final data = await rootBundle.load('assets/$asset');
      expect(data.lengthInBytes, greaterThan(0));
    }
  });
}
