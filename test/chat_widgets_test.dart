import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/chats_page.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/chat_menu_row.dart';
import 'package:palturo/widgets/chat_search_sheet.dart';

void main() {
  testWidgets('search sheet survives its dismissal animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showModalBottomSheet<Map<String, dynamic>>(
                        context: context,
                        isScrollControlled: true,
                        builder:
                            (_) => ChatSearchSheet(
                              messages: const [
                                {
                                  'body': 'Hello there',
                                  'created_at': '2026-11-05',
                                },
                                {'body': 'Another message', 'created_at': ''},
                              ],
                              formatTime: (_) => 'Nov 5',
                            ),
                      ),
                  child: const Text('Open search'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    expect(find.text('Hello there'), findsOneWidget);

    Navigator.of(tester.element(find.byType(ChatSearchSheet))).pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a search result pops cleanly', (tester) async {
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    selected = await showModalBottomSheet<Map<String, dynamic>>(
                      context: context,
                      isScrollControlled: true,
                      builder:
                          (_) => ChatSearchSheet(
                            messages: const [
                              {'body': 'Match me', 'created_at': ''},
                            ],
                            formatTime: (_) => '',
                          ),
                    );
                  },
                  child: const Text('Open search'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'match');
    await tester.pump();
    await tester.tap(find.text('Match me'));
    await tester.pumpAndSettle();

    expect(selected?['body'], 'Match me');
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu rows fit at 200% text', (tester) async {
    for (final label in const [
      'Mute notifications',
      'Unmute notifications',
      'Mark as unread',
      'Retry failed messages',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 256,
                  child: ChatMenuRow(label: label, icon: Icons.refresh),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('chat row shows presence and time at 360/200%', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 360,
              child: ChatListItem(
                name: 'Grace Lim',
                message: 'Kumusta! Gusto mo bang mag-exchange ng adobo recipe?',
                time: 'Yesterday',
                presence: 'Active 20m ago',
                skillName: 'Binangkal',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Active 20m ago'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
