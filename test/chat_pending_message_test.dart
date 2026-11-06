import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/chat_pending_message.dart';
import 'package:palturo/theme/theme.dart';

PendingChatMessage pending(PendingMessageStatus status) => PendingChatMessage(
  localId: 'p1',
  body: 'See you at the market tomorrow.',
  createdAt: DateTime(2026),
  status: status,
);

void main() {
  testWidgets('sending bubble appears immediately with a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: PendingMessageBubble(
            message: pending(PendingMessageStatus.sending),
          ),
        ),
      ),
    );
    expect(find.text('See you at the market tomorrow.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Not sent'), findsNothing);
  });

  testWidgets('failed bubble keeps the message and retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: PendingMessageBubble(
            message: pending(PendingMessageStatus.failed),
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    expect(find.text('See you at the market tomorrow.'), findsOneWidget);
    expect(find.text('Not sent'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
