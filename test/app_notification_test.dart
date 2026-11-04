import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/models/app_notification.dart';

void main() {
  test('parses an enriched notification row', () {
    final item = AppNotification.fromRow({
      'id': 'n1',
      'kind': 'connection_request',
      'payload': {'connection_id': 'c1', 'requester_id': 'u1'},
      'read_at': null,
      'created_at': '2026-11-04T10:00:00Z',
      'actor_id': 'u1',
      'actor_name': 'RJ Castillano',
      'actor_avatar': 'https://example.test/rj.png',
      'skill_name': 'Barong Embroidery',
      'role': 'mentor',
      'connection_status': 'pending',
    });

    expect(item.id, 'n1');
    expect(item.kind, AppNotificationKind.connectionRequest);
    expect(item.isUnread, isTrue);
    expect(item.connectionId, 'c1');
    expect(item.actorId, 'u1');
    expect(item.actorName, 'RJ Castillano');
    expect(item.actorAvatar, contains('rj.png'));
    expect(item.skillName, 'Barong Embroidery');
    expect(item.role, 'mentor');
    expect(item.connectionStatus, 'pending');
    expect(item.createdAt, DateTime.utc(2026, 11, 4, 10));
  });

  test('falls back to payload and handles read state', () {
    final item = AppNotification.fromRow({
      'id': 'n2',
      'kind': 'request_accepted',
      'payload': {
        'connection_id': 'c2',
        'responder_id': 'u2',
        'responder_name': 'Grace Lim',
        'skill': 'Binangkal',
      },
      'read_at': '2026-11-04T11:00:00Z',
      'created_at': '2026-11-04T10:00:00Z',
    });

    expect(item.kind.isMatch, isTrue);
    expect(item.isUnread, isFalse);
    expect(item.actorId, 'u2');
    expect(item.actorName, 'Grace Lim');
    expect(item.skillLabel, 'Binangkal');
    expect(item.role, isNull);
  });

  test('unknown kinds and malformed payloads stay safe', () {
    final item = AppNotification.fromRow({
      'id': 'n3',
      'kind': 'mystery',
      'payload': 'not-a-map',
      'created_at': 'not-a-date',
    });

    expect(item.kind, AppNotificationKind.unknown);
    expect(item.payload, isEmpty);
    expect(item.connectionId, isNull);
    expect(item.actorName, isNull);
    expect(item.skillName, isNull);
    expect(item.isUnread, isTrue);
  });

  test('copyWith clears and sets read state', () {
    final item = AppNotification.fromRow({
      'id': 'n4',
      'kind': 'feedback_ready',
      'payload': {'connection_id': 'c4'},
      'created_at': '2026-11-04T10:00:00Z',
    });

    final read = item.copyWith(readAt: DateTime.utc(2026, 11, 4, 12));
    expect(read.isUnread, isFalse);
    expect(read.connectionId, 'c4');

    final unreadAgain = read.copyWith(clearReadAt: true);
    expect(unreadAgain.isUnread, isTrue);
  });

  test('toRow keeps fields usable by the activity presenter', () {
    final item = AppNotification.fromRow({
      'id': 'n5',
      'kind': 'skill_moderation',
      'payload': {'skill': 'Parol Making'},
      'created_at': '2026-11-04T10:00:00Z',
      'actor_name': 'Nanay Cita',
      'skill_name': 'Parol Making',
    });

    final row = item.toRow();
    expect(row['id'], 'n5');
    expect(row['kind'], 'skill_moderation');
    expect(row['actor_name'], 'Nanay Cita');
    expect(row['skill_name'], 'Parol Making');
    expect(row['created_at'], isA<String>());
  });
}
