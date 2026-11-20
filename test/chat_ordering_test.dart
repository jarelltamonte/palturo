import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/match_api.dart';

ConversationLite _conversation(String id, DateTime? activityAt) {
  return ConversationLite(
    connectionId: id,
    status: 'accepted',
    otherUserId: 'user-$id',
    otherName: 'Pal $id',
    otherRole: 'mentor',
    lastMessage: activityAt == null ? null : 'Message from $id',
    // get_conversations returns the match time as last_at for a new Pal.
    lastAt: activityAt,
    unread: 0,
  );
}

ConversationLite _newMatch(String id, DateTime matchedAt) {
  return ConversationLite(
    connectionId: id,
    status: 'accepted',
    otherUserId: 'user-$id',
    otherName: 'Pal $id',
    otherRole: 'mentor',
    lastAt: matchedAt,
    unread: 0,
  );
}

void main() {
  test('messages and new matches share one recency order', () {
    final now = DateTime(2026, 11, 18, 12);

    // State 1: U1, U2, U3 by activity.
    final list = [
      _conversation('u3', now.subtract(const Duration(minutes: 50))),
      _conversation('u1', now.subtract(const Duration(minutes: 60))),
      _conversation('u2', now.subtract(const Duration(minutes: 30))),
    ];
    sortConversationsByRecency(list);
    expect(list.map((c) => c.connectionId), ['u2', 'u3', 'u1']);

    // State 2: U2 sends a message.
    list.first = _conversation('u2', now);
    sortConversationsByRecency(list);
    expect(list.map((c) => c.connectionId), ['u2', 'u3', 'u1']);

    // State 3: U4 accepts and becomes a new conversation at the top.
    list.add(_newMatch('u4', now.add(const Duration(minutes: 2))));
    sortConversationsByRecency(list);
    expect(list.map((c) => c.connectionId), ['u4', 'u2', 'u3', 'u1']);

    // State 4: U3 replies and jumps back above the new match.
    final u3 = list.indexWhere((c) => c.connectionId == 'u3');
    list[u3] = _conversation('u3', now.add(const Duration(minutes: 4)));
    sortConversationsByRecency(list);
    expect(list.map((c) => c.connectionId), ['u3', 'u4', 'u2', 'u1']);
  });

  test('rows without an activity time keep their order at the bottom', () {
    final now = DateTime(2026, 11, 18, 12);
    final list = [
      _conversation('unknown-a', null),
      _conversation('started', now.subtract(const Duration(days: 2))),
      _conversation('unknown-b', null),
    ];

    sortConversationsByRecency(list);

    expect(list.map((c) => c.connectionId), [
      'started',
      'unknown-a',
      'unknown-b',
    ]);
  });
}
