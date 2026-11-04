import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/models/app_notification.dart';
import 'package:palturo/services/local_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notification ids are deterministic and bounded', () {
    final service = LocalNotificationService.instance;

    final first = service.notificationIdFor('notification-1');
    final second = service.notificationIdFor('notification-1');
    final other = service.notificationIdFor('notification-2');

    expect(first, second);
    expect(first, isNot(other));
    expect(first, greaterThanOrEqualTo(1));
    expect(first, lessThanOrEqualTo(0x7fffffff));
  });

  test('permission state distinguishes not-asked from denied', () {
    final service = LocalNotificationService.instance;

    expect(
      service.resolvePermissionStatus(enabled: true, asked: false),
      NotificationPermissionStatus.granted,
    );
    expect(
      service.resolvePermissionStatus(enabled: false, asked: false),
      NotificationPermissionStatus.unknown,
    );
    expect(
      service.resolvePermissionStatus(enabled: false, asked: true),
      NotificationPermissionStatus.denied,
    );
    expect(
      service.resolvePermissionStatus(enabled: null, asked: true),
      NotificationPermissionStatus.unknown,
    );
  });

  test('channel matrix honors sound and vibration independently', () {
    final service = LocalNotificationService.instance;

    expect(
      service.channelIdFor(
        AppNotificationKind.unknown,
        sound: true,
        vibration: true,
        message: true,
      ),
      'palturo_messages',
    );
    expect(
      service.channelIdFor(
        AppNotificationKind.unknown,
        sound: true,
        vibration: false,
        message: true,
      ),
      'palturo_messages_sound',
    );
    expect(
      service.channelIdFor(
        AppNotificationKind.unknown,
        sound: false,
        vibration: true,
        message: true,
      ),
      'palturo_messages_vibration',
    );
    expect(
      service.channelIdFor(
        AppNotificationKind.unknown,
        sound: false,
        vibration: false,
        message: true,
      ),
      'palturo_messages_quiet',
    );
    expect(
      service.channelIdFor(
        AppNotificationKind.connectionRequest,
        sound: true,
        vibration: true,
      ),
      'palturo_requests',
    );
  });

  test('chat payload carries the conversation context', () {
    final item = AppNotification.fromRow({
      'id': 'n1',
      'kind': 'request_accepted',
      'payload': {'connection_id': 'c1'},
      'created_at': '2026-11-05T10:00:00Z',
      'actor_name': 'Grace Lim',
      'skill_name': 'Binangkal',
      'role': 'mentor',
      'actor_avatar': 'https://example.test/grace.png',
      'connection_status': 'accepted',
    });

    final payload = LocalNotificationService.instance.payloadFor(item);

    expect(payload['route'], 'chat');
    expect(payload['connectionId'], 'c1');
    expect(payload['name'], 'Grace Lim');
    expect(payload['skillName'], 'Binangkal');
    expect(payload['role'], 'mentor');
    expect(payload['avatarUrl'], contains('grace.png'));
  });

  test('request payload routes to the incoming list', () {
    final item = AppNotification.fromRow({
      'id': 'n2',
      'kind': 'connection_request',
      'payload': {'connection_id': 'c2'},
      'created_at': '2026-11-05T10:00:00Z',
      'actor_name': 'RJ',
      'skill_name': 'Barong',
      'role': 'mentor',
    });

    final payload = LocalNotificationService.instance.payloadFor(item);

    expect(payload['route'], 'requests');
    expect(payload['view'], 'incoming');
  });

  test('unknown routing falls back to Activity', () {
    final item = AppNotification.fromRow({
      'id': 'n3',
      'kind': 'skill_moderation',
      'payload': {},
      'created_at': '2026-11-05T10:00:00Z',
    });

    final payload = LocalNotificationService.instance.payloadFor(item);

    expect(payload['route'], 'profile');
  });
}
