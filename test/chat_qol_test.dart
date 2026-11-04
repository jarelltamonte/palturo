import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/utils/chat_unread.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/match_api.dart';

ConversationLite conversation({int unread = 0, bool markedUnread = false}) {
  return ConversationLite(
    connectionId: 'c1',
    status: 'accepted',
    otherUserId: 'u1',
    otherName: 'Grace Lim',
    otherRole: 'mentor',
    unread: unread,
    markedUnread: markedUnread,
  );
}

void main() {
  test('mute is active only until the timestamp passes', () {
    final now = DateTime(2026, 11, 5, 12);

    expect(isMuteActive(null, now: now), isFalse);
    expect(isMuteActive(now.add(const Duration(hours: 1)), now: now), isTrue);
    expect(
      isMuteActive(now.subtract(const Duration(minutes: 1)), now: now),
      isFalse,
    );
  });

  test('manual unread keeps the conversation indicator on', () {
    expect(conversationHasUnread(conversation()), isFalse);
    expect(conversationHasUnread(conversation(unread: 2)), isTrue);
    expect(conversationHasUnread(conversation(markedUnread: true)), isTrue);
  });

  test('conversation copyWith updates mute and unread state', () {
    final base = conversation();

    final muted = base.copyWith(
      mutedUntil: DateTime(2026, 11, 6),
      markedUnread: true,
    );
    expect(muted.mutedUntil, DateTime(2026, 11, 6));
    expect(muted.markedUnread, isTrue);

    final cleared = muted.copyWith(clearMutedUntil: true, markedUnread: false);
    expect(cleared.mutedUntil, isNull);
    expect(cleared.markedUnread, isFalse);
  });
}
