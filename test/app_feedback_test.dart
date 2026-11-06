import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/app_feedback.dart';

void main() {
  testWidgets('success and error feedback replace each other', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    showAppSuccess(pageContext, 'Saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved'), findsOneWidget);

    showAppError(pageContext, 'Could not save');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Could not save'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('undo action runs once and dismisses', (tester) async {
    late BuildContext pageContext;
    var undone = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    showAppSnackBar(
      pageContext,
      'Request withdrawn',
      actionLabel: 'Undo',
      onAction: () => undone++,
      duration: const Duration(seconds: 5),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(undone, 1);
  });
}
