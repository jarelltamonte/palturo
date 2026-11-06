import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/models/incoming_message_event.dart';

void main() {
  test('preview collapses whitespace', () {
    final event = IncomingMessageEvent(
      connectionId: 'c1',
      senderName: 'Grace',
      body: '  Hello\n\n  there\tfriend  ',
      createdAt: DateTime.utc(2026, 11, 4),
    );

    expect(event.preview, 'Hello there friend');
  });

  test('preview caps long messages at 120 characters', () {
    final event = IncomingMessageEvent(
      connectionId: 'c1',
      senderName: 'Grace',
      body: 'a' * 200,
      createdAt: DateTime.utc(2026, 11, 4),
    );

    expect(event.preview.length, 120);
    expect(event.preview.endsWith('...'), isTrue);
  });
}
