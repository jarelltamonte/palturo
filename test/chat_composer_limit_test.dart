import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/theme/theme.dart';

void main() {
  testWidgets('the composer caps messages at the server limit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: const ChatRoom(connectionId: null, name: 'Test Pal'),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    await tester.enterText(field, 'a' * 4500);
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text.length, 4000);
  });
}
