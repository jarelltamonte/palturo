import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/utils/chat_time_formatter.dart';

void main() {
  // Friday, 23 October 2026, 12:00 local.
  final now = DateTime(2026, 10, 23, 12);

  group('ChatTimeFormatter', () {
    test('formats 12-hour time', () {
      expect(
        ChatTimeFormatter.formatTimeOnly(DateTime(2026, 1, 1, 0, 5)),
        '12:05 AM',
      );
      expect(
        ChatTimeFormatter.formatTimeOnly(DateTime(2026, 1, 1, 13, 7)),
        '1:07 PM',
      );
    });

    test('formats the chat-list preview for every age bucket', () {
      expect(ChatTimeFormatter.formatChatListTime(null), '');
      expect(
        ChatTimeFormatter.formatChatListTime(
          DateTime(2026, 10, 23, 9, 41),
          now: now,
        ),
        '9:41 AM',
      );
      expect(
        ChatTimeFormatter.formatChatListTime(
          DateTime(2026, 10, 22, 9, 41),
          now: now,
        ),
        'Yesterday',
      );
      expect(
        ChatTimeFormatter.formatChatListTime(DateTime(2026, 10, 21), now: now),
        'Wed',
      );
      expect(
        ChatTimeFormatter.formatChatListTime(DateTime(2026, 10, 17), now: now),
        'Sat',
      );
      expect(
        ChatTimeFormatter.formatChatListTime(DateTime(2026, 1, 5), now: now),
        'Jan 5',
      );
      expect(
        ChatTimeFormatter.formatChatListTime(DateTime(2025, 12, 31), now: now),
        'Dec 31, 2025',
      );
    });

    test('formats messenger headers for every age bucket', () {
      expect(
        ChatTimeFormatter.formatMessengerHeader(
          DateTime(2026, 10, 23, 9, 41),
          now: now,
        ),
        '9:41 AM',
      );
      expect(
        ChatTimeFormatter.formatMessengerHeader(
          DateTime(2026, 10, 22, 9, 41),
          now: now,
        ),
        'Yesterday 9:41 AM',
      );
      expect(
        ChatTimeFormatter.formatMessengerHeader(
          DateTime(2026, 10, 21, 9, 41),
          now: now,
        ),
        'Wed 9:41 AM',
      );
      expect(
        ChatTimeFormatter.formatMessengerHeader(
          DateTime(2026, 1, 5, 9, 41),
          now: now,
        ),
        'Jan 5, 9:41 AM',
      );
      expect(
        ChatTimeFormatter.formatMessengerHeader(
          DateTime(2025, 12, 31, 9, 41),
          now: now,
        ),
        'Dec 31, 2025, 9:41 AM',
      );
    });

    test('messenger headers split on day or 20-minute gaps', () {
      final current = DateTime(2026, 1, 1, 12);
      expect(
        ChatTimeFormatter.shouldShowMessengerHeader(null, current),
        isTrue,
      );
      expect(
        ChatTimeFormatter.shouldShowMessengerHeader(
          current.subtract(const Duration(minutes: 19)),
          current,
        ),
        isFalse,
      );
      expect(
        ChatTimeFormatter.shouldShowMessengerHeader(
          current.subtract(const Duration(minutes: 20)),
          current,
        ),
        isTrue,
      );
      expect(
        ChatTimeFormatter.shouldShowMessengerHeader(
          current.subtract(const Duration(days: 1)),
          current,
        ),
        isTrue,
      );
    });
  });
}
