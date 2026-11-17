import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/app_feedback.dart';

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required Duration duration,
  bool withAction = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: lightMode,
      home: Scaffold(
        body: Builder(
          builder:
              (context) => Center(
                child: ElevatedButton(
                  onPressed:
                      () => showAppSnackBar(
                        context,
                        'Connection request sent',
                        duration: duration,
                        actionLabel: withAction ? 'Undo' : null,
                        onAction: withAction ? () {} : null,
                      ),
                  child: const Text('send'),
                ),
              ),
        ),
      ),
    ),
  );
}

Future<void> _send(WidgetTester tester) async {
  await tester.tap(find.text('send'));
  await tester.pumpAndSettle();
  expect(find.text('Connection request sent'), findsOneWidget);
}

void main() {
  testWidgets('snack bar with an action dismisses on its own', (tester) async {
    // SnackBar defaults to persist when it has an action, which is exactly the
    // "request sent / Undo" message that used to stay on screen forever.
    await _pumpLauncher(
      tester,
      duration: const Duration(seconds: 2),
      withAction: true,
    );

    await _send(tester);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Connection request sent'), findsNothing);
  });

  testWidgets('action snack bar dismisses with accessible navigation', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpLauncher(
      tester,
      duration: const Duration(seconds: 2),
      withAction: true,
    );

    await _send(tester);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Connection request sent'), findsNothing);
  });

  testWidgets('snack bar without an action still dismisses', (tester) async {
    await _pumpLauncher(tester, duration: const Duration(seconds: 2));

    await _send(tester);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Connection request sent'), findsNothing);
  });
}

