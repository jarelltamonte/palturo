import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_flow.dart';
import 'package:palturo/theme/theme.dart';

Widget _host(Future<void> Function() onSkip) {
  return MaterialApp(
    theme: lightMode,
    home: Builder(
      builder:
          (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => confirmOnboardingSkip(context, onSkip),
                child: const Text('Leave'),
              ),
            ),
          ),
    ),
  );
}

void main() {
  testWidgets('finish later confirms and calls the exit path', (tester) async {
    var skipped = 0;
    await tester.pumpWidget(
      _host(() async {
        skipped++;
      }),
    );

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Finish later?'), findsOneWidget);

    await tester.tap(find.text('Finish later'));
    await tester.pumpAndSettle();
    expect(skipped, 1);
    expect(find.text('Finish later?'), findsNothing);
  });

  testWidgets('a failed exit still closes the dialog', (tester) async {
    await tester.pumpWidget(
      _host(() async {
        throw Exception('storage unavailable');
      }),
    );

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish later'));
    await tester.pumpAndSettle();

    expect(find.text('Finish later?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keep editing leaves the user where they are', (tester) async {
    var skipped = 0;
    await tester.pumpWidget(
      _host(() async {
        skipped++;
      }),
    );

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(skipped, 0);
    expect(find.text('Finish later?'), findsNothing);
  });
}
