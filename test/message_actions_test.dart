import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/theme/theme.dart';

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required bool canEdit,
  required bool canDelete,
  required ValueChanged<String?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: lightMode,
      home: Scaffold(
        body: Builder(
          builder:
              (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await showMessageActionSheet(
                      context,
                      canEdit: canEdit,
                      canDelete: canDelete,
                    );
                    onResult(result);
                  },
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('own message offers copy, edit, and delete', (tester) async {
    String? result;
    await _pumpLauncher(
      tester,
      canEdit: true,
      canDelete: true,
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Edit message'), findsOneWidget);
    expect(find.text('Delete message'), findsOneWidget);

    await tester.tap(find.text('Edit message'));
    await tester.pumpAndSettle();
    expect(result, 'edit');
  });

  testWidgets('peer message offers copy only', (tester) async {
    String? result;
    await _pumpLauncher(
      tester,
      canEdit: false,
      canDelete: false,
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Edit message'), findsNothing);
    expect(find.text('Delete message'), findsNothing);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(result, 'copy');
  });
}
