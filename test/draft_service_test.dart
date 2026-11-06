import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/draft_service.dart';
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
    await DraftService.instance.clearAll();
  });

  test('saves, restores, and clears a per-conversation draft', () async {
    final drafts = DraftService.instance;

    await drafts.saveDraft('c1', 'Kumusta! Gusto mo bang');
    await drafts.saveDraft('c2', 'Another draft');

    expect(drafts.draftFor('c1'), 'Kumusta! Gusto mo bang');
    expect(drafts.hasDraft('c2'), isTrue);
    expect(drafts.draftFor('unknown'), isNull);

    await drafts.clearDraft('c1');
    expect(drafts.hasDraft('c1'), isFalse);
    expect(drafts.draftFor('c2'), 'Another draft');
  });

  test('blank drafts are treated as cleared', () async {
    final drafts = DraftService.instance;

    await drafts.saveDraft('c1', '   ');
    expect(drafts.hasDraft('c1'), isFalse);

    await drafts.saveDraft('c1', 'text');
    await drafts.saveDraft('c1', '');
    expect(drafts.hasDraft('c1'), isFalse);
  });

  test('drafts reload from storage', () async {
    await DraftService.instance.saveDraft('c1', 'Saved draft');

    DraftService.instance.debugResetForTest();
    expect(DraftService.instance.hasDraft('c1'), isFalse);

    await DraftService.instance.init();
    expect(DraftService.instance.draftFor('c1'), 'Saved draft');
  });

  test('clearAll removes every draft and the stored blob', () async {
    await DraftService.instance.saveDraft('c1', 'one');
    await DraftService.instance.saveDraft('c2', 'two');

    await DraftService.instance.clearAll();

    expect(DraftService.instance.hasDraft('c1'), isFalse);
    expect(DraftService.instance.hasDraft('c2'), isFalse);
    final raw = await PreferencesService.instance.getString('chat_drafts');
    expect(raw, '{}');
  });
}
