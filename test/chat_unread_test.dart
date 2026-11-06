import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/utils/chat_unread.dart';
import 'package:palturo/services/match_api.dart';

ConversationLite conversation(int unread) => ConversationLite(
  connectionId: 'c1',
  status: 'accepted',
  otherUserId: 'u1',
  otherName: 'RJ Castillano',
  otherRole: 'mentor',
  unread: unread,
);

void main() {
  test('unread filter data ignores the notification preference', () {
    final unread = conversation(3);
    expect(conversationHasUnread(unread), isTrue);
    expect(showConversationUnreadIndicator(unread, false), isFalse);
    expect(showConversationUnreadIndicator(unread, true), isTrue);
  });

  test('read conversation stays read with badges enabled', () {
    final read = conversation(0);
    expect(conversationHasUnread(read), isFalse);
    expect(showConversationUnreadIndicator(read, true), isFalse);
  });
}
