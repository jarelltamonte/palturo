import 'package:flutter/material.dart';
import 'package:palturo/models/app_notification.dart';
import 'package:palturo/models/incoming_message_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/settings/notification_preferences_page.dart';
import 'package:palturo/services/notification_presenter.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PreferencesService.instance.init();
  });

  test('defaults are on and quiet hours are off', () {
    final prefs = PreferencesService.instance;

    expect(prefs.notificationsEnabled, isTrue);
    expect(prefs.messageNotificationsEnabled, isTrue);
    expect(prefs.requestNotificationsEnabled, isTrue);
    expect(prefs.activityNotificationsEnabled, isTrue);
    expect(prefs.messagePreviewsEnabled, isTrue);
    expect(prefs.quietHoursEnabled, isFalse);
  });

  test('category setters persist', () async {
    final prefs = PreferencesService.instance;

    await prefs.setMessageNotificationsEnabled(false);
    await prefs.setRequestNotificationsEnabled(false);
    await prefs.setActivityNotificationsEnabled(false);
    await prefs.setMessagePreviewsEnabled(false);

    expect(prefs.messageNotificationsEnabled, isFalse);
    expect(prefs.requestNotificationsEnabled, isFalse);
    expect(prefs.activityNotificationsEnabled, isFalse);
    expect(prefs.messagePreviewsEnabled, isFalse);
    expect(await prefs.getBool('message_notifications_enabled'), isFalse);
    expect(await prefs.getBool('message_previews_enabled'), isFalse);
  });

  test('quiet hours handle overnight and daytime windows', () async {
    final prefs = PreferencesService.instance;

    await prefs.setQuietWindow(startMinutes: 22 * 60, endMinutes: 7 * 60);
    await prefs.setQuietHoursEnabled(true);

    expect(prefs.isQuietHours(DateTime(2026, 1, 1, 23)), isTrue);
    expect(prefs.isQuietHours(DateTime(2026, 1, 1, 2)), isTrue);
    expect(prefs.isQuietHours(DateTime(2026, 1, 1, 12)), isFalse);
    expect(prefs.isQuietHours(DateTime(2026, 1, 1, 7)), isFalse);

    await prefs.setQuietWindow(startMinutes: 13 * 60, endMinutes: 14 * 60);
    expect(prefs.isQuietHours(DateTime(2026, 1, 1, 13, 30)), isTrue);
    expect(prefs.isQuietHours(DateTime(2026, 1, 1, 15)), isFalse);

    await prefs.setQuietWindow(startMinutes: 10 * 60, endMinutes: 10 * 60);
    expect(prefs.isQuietHours(DateTime(2026, 1, 1, 10)), isFalse);
  });

  test(
    'presenter category mapping follows request and activity flags',
    () async {
      final prefs = PreferencesService.instance;

      await prefs.setRequestNotificationsEnabled(false);
      expect(
        notificationKindEnabled(AppNotificationKind.connectionRequest),
        isFalse,
      );
      expect(
        notificationKindEnabled(AppNotificationKind.requestAccepted),
        isFalse,
      );
      expect(
        notificationKindEnabled(AppNotificationKind.feedbackReady),
        isTrue,
      );

      await prefs.setActivityNotificationsEnabled(false);
      expect(
        notificationKindEnabled(AppNotificationKind.feedbackReady),
        isFalse,
      );
      expect(notificationKindEnabled(AppNotificationKind.unknown), isFalse);
    },
  );

  test('message preview privacy and quiet-hours feedback rules', () async {
    final prefs = PreferencesService.instance;
    final event = IncomingMessageEvent(
      connectionId: 'c1',
      peerUserId: 'u1',
      senderName: 'Grace',
      body: 'Private message text',
      createdAt: DateTime.utc(2026, 11, 4),
    );

    await prefs.setMessagePreviewsEnabled(false);
    expect(messageBannerBody(event), 'New message');
    await prefs.setMessagePreviewsEnabled(true);
    expect(messageBannerBody(event), 'Private message text');

    await prefs.setQuietWindow(startMinutes: 22 * 60, endMinutes: 7 * 60);
    await prefs.setQuietHoursEnabled(true);
    expect(
      notificationFeedbackAllowed(now: DateTime(2026, 11, 4, 23)),
      isFalse,
    );
    expect(notificationFeedbackAllowed(now: DateTime(2026, 11, 4, 12)), isTrue);
  });

  test('permission asked flag persists', () async {
    final prefs = PreferencesService.instance;

    await prefs.setNotificationPermissionAsked(true);

    expect(prefs.notificationPermissionAsked, isTrue);
    expect(await prefs.getBool('notification_permission_asked'), isTrue);
  });

  testWidgets('page exposes categories and master gating', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const NotificationPreferencesPage()),
    );

    expect(
      find.widgetWithText(SwitchListTile, 'Notifications'),
      findsOneWidget,
    );
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Requests & matches'), findsOneWidget);
    expect(find.text('Activity updates'), findsOneWidget);
    expect(find.text('Show message text'), findsOneWidget);
    expect(find.widgetWithText(SwitchListTile, 'Quiet hours'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Turn on notifications to use this.'), findsNWidgets(5));
  });

  testWidgets('page survives 360px at 200% text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: const NotificationPreferencesPage(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Sound'),
      300,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.widgetWithText(SwitchListTile, 'Quiet hours'),
      300,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('message preview and quiet hours rows update', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const NotificationPreferencesPage()),
    );

    expect(
      find.text('Kumusta! Gusto mo bang mag-exchange ng adobo recipe?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Show message text'));
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Quiet hours'));
    await tester.pumpAndSettle();
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
  });
}
