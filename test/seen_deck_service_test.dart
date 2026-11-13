import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/services/seen_deck_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PreferencesService.instance.init();
    SeenDeckService.instance.userIdOverride = 'test-user';
  });

  tearDown(() {
    SeenDeckService.instance.userIdOverride = null;
  });

  test('mark, persist, and unmark a seen card', () async {
    final service = SeenDeckService.instance;

    expect(await service.load(), isEmpty);

    await service.markSeen('p1');
    await service.markSeen('p2');
    expect(await service.load(), {'p1', 'p2'});

    final raw = await PreferencesService.instance.getString(
      'deck_seen_v1_test-user',
    );
    expect(SeenDeckService.parse(raw), {'p1', 'p2'});

    await service.unmarkSeen('p1');
    expect(await service.load(), {'p2'});

    final stored = await PreferencesService.instance.getString(
      'deck_seen_v1_test-user',
    );
    expect(SeenDeckService.parse(stored), {'p2'});
  });

  test('parse ignores malformed and non-list payloads', () {
    expect(SeenDeckService.parse(null), isEmpty);
    expect(SeenDeckService.parse(''), isEmpty);
    expect(SeenDeckService.parse('not json'), isEmpty);
    expect(SeenDeckService.parse('{"a":1}'), isEmpty);
    expect(SeenDeckService.parse('["p1","","p2",3]'), {'p1', 'p2'});
  });
}
