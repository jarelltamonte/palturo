import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/card_guide_service.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PreferencesService.instance.init();
    CardGuideService.instance.userIdOverride = 'guide-user';
  });

  tearDown(() {
    CardGuideService.instance.userIdOverride = null;
  });

  test(
    'shows for an empty first deck and is suppressed after completion',
    () async {
      final service = CardGuideService.instance;

      expect(await service.shouldShow(const <String>{}), isTrue);
      await service.markSeen();
      expect(await service.shouldShow(const <String>{}), isFalse);
    },
  );

  test('seen cards suppress the guide even when the flag is unset', () async {
    expect(
      await CardGuideService.instance.shouldShow(const {'person-1'}),
      isFalse,
    );
  });

  test('the seen flag is scoped per account', () async {
    final service = CardGuideService.instance;
    await service.markSeen();
    expect(await service.shouldShow(const <String>{}), isFalse);

    service.userIdOverride = 'another-user';
    expect(await service.shouldShow(const <String>{}), isTrue);
  });
}
