import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/models/app_notification.dart';
import 'package:palturo/screen/notifications_page.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

AppNotification item(String kind, {DateTime? readAt, DateTime? createdAt}) {
  return AppNotification.fromRow({
    'id': 'n-$kind-${readAt == null}-${createdAt?.toIso8601String() ?? ''}',
    'kind': kind,
    'payload': const {},
    'read_at': readAt?.toIso8601String(),
    'created_at': (createdAt ?? DateTime.utc(2026, 11, 5)).toIso8601String(),
  });
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PreferencesService.instance.init();
  });

  test('activity filters separate requests from updates', () {
    final unreadRequest = item(
      'connection_request',
      createdAt: DateTime.utc(2026, 11, 5),
    );
    final readUpdate = item(
      'feedback_ready',
      readAt: DateTime.utc(2026, 11, 5, 1),
    );
    final match = item('request_accepted');
    final moderation = item('skill_moderation');

    expect(activityMatchesFilter(unreadRequest, ActivityFilter.all), isTrue);
    expect(activityMatchesFilter(unreadRequest, ActivityFilter.unread), isTrue);
    expect(
      activityMatchesFilter(unreadRequest, ActivityFilter.requests),
      isTrue,
    );
    expect(
      activityMatchesFilter(unreadRequest, ActivityFilter.updates),
      isFalse,
    );

    expect(activityMatchesFilter(readUpdate, ActivityFilter.unread), isFalse);
    expect(activityMatchesFilter(readUpdate, ActivityFilter.updates), isTrue);
    expect(activityMatchesFilter(match, ActivityFilter.requests), isTrue);
    expect(activityMatchesFilter(moderation, ActivityFilter.updates), isTrue);
  });

  test('activity day labels use Today, Yesterday, then a date', () {
    final now = DateTime(2026, 11, 5, 12);

    expect(activityDayLabel(DateTime(2026, 11, 5), now: now), 'Today');
    expect(activityDayLabel(DateTime(2026, 11, 4), now: now), 'Yesterday');
    expect(activityDayLabel(DateTime(2026, 11, 1), now: now), 'Nov 1');
    expect(activityDayLabel(DateTime(2026, 1, 9), now: now), 'Jan 9');
  });

  test('saved filter maps round-trip and tolerate junk', () async {
    final prefs = PreferencesService.instance;

    expect(await prefs.getFilterMap('chat_filters_v1'), isNull);

    await prefs.setFilterMap('chat_filters_v1', {
      'role': 'mentor',
      'status': 'unread',
    });
    final restored = await prefs.getFilterMap('chat_filters_v1');

    expect(restored?['role'], 'mentor');
    expect(restored?['status'], 'unread');

    await prefs.setString('bad_filters', 'not-json');
    expect(await prefs.getFilterMap('bad_filters'), isNull);
  });
}
