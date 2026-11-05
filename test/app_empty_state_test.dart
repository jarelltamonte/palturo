import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/app_empty_state.dart';

void main() {
  testWidgets('renders copy and fires the action', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: AppEmptyState(
            title: 'No chats yet',
            message: 'Send a request to meet your first Pal.',
            actionLabel: 'Start swiping',
            onAction: () => tapped++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No chats yet'), findsOneWidget);
    expect(find.text('Send a request to meet your first Pal.'), findsOneWidget);
    expect(find.byType(Lottie), findsOneWidget);

    await tester.tap(find.text('Start swiping'));
    expect(tapped, 1);
  });

  testWidgets('filtered variant hides the illustration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: AppEmptyState(
            showIllustration: false,
            title: 'No activity yet',
            actionLabel: 'Show all',
            onAction: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No activity yet'), findsOneWidget);
    expect(find.byType(Lottie), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom padding keeps the action above the tab bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
        home: Scaffold(
          body: AppEmptyState(
            title: 'No chats yet',
            message: 'Send a request to meet your first Pal.',
            actionLabel: 'Start swiping',
            onAction: () {},
            bottomPadding: 124,
          ),
        ),
      ),
    );
    await tester.pump();

    final empty = tester.widget<AppEmptyState>(find.byType(AppEmptyState));
    expect(empty.bottomPadding, 124);
    final action = tester.getRect(find.text('Start swiping'));
    expect(action.bottom, lessThan(640 - 94));
    expect(tester.takeException(), isNull);
  });
}
