import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/request_match_sheet.dart';
import 'package:palturo/theme/theme.dart';

void main() {
  testWidgets('match sheet exposes both next actions', (tester) async {
    RequestMatchAction? action;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    action = await showRequestMatchSheet(
                      context,
                      name: 'RJ Castillano',
                      skillName: 'Barong Embroidery',
                    );
                  },
                  child: const Text('Open'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('You are now Pals with RJ Castillano'), findsOneWidget);
    expect(find.text('Matched on Barong Embroidery'), findsOneWidget);
    expect(find.text('Say hello'), findsOneWidget);
    expect(find.text('Keep browsing'), findsOneWidget);
    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();
    expect(action, RequestMatchAction.sayHello);
  });
}
