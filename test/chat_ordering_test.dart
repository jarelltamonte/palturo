import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/match_api.dart';

ConversationLite _conversation(String id, DateTime? lastAt) {
  return ConversationLite(
    connectionId: id,
    status: 'accepted',
    otherUserId: 'user-$id',
    otherName: 'Pal $id',
    otherRole: 'mentor',
    lastMessage: lastAt == null ? null : 'Message from $id',
    lastAt: lastAt,
    unread: 0,
  );
}

void main() {
  test('latest message sorts first and new Pals stay below', () {
    final now = DateTime(2026, 11, 18, 12);
    final list = [
      _conversation('new-pal-a', null),
      _conversation('older', now.subtract(const Duration(hours: 3))),
      _conversation('newest', now),
      _conversation('new-pal-b', null),
      _conversation('middle', now.subtract(const Duration(minutes: 20))),
    ];

    sortConversationsByRecency(list);

    expect(list.map((c) => c.connectionId).toList(), [
      'newest',
      'middle',
      'older',
      'new-pal-a',
      'new-pal-b',
    ]);
  });

  test('a conversation without messages never outranks a started chat', () {
    final now = DateTime(2026, 11, 18, 12);
    final list = [
      _conversation('brand-new', null),
      _conversation('old-chat', now.subtract(const Duration(days: 2))),
    ];

    sortConversationsByRecency(list);

    expect(list.map((c) => c.connectionId).toList(), ['old-chat', 'brand-new']);
  });
}
