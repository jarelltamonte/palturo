import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/exhausted_deck_view.dart';

void main() {
  testWidgets('exhausted deck shows the note and wires every action', (
    tester,
  ) async {
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: ExhaustedDeckView(
            onExplore: () => calls.add('explore'),
            onViewAgain: () => calls.add('view'),
            onBrowse: () => calls.add('browse'),
            onUpdateProfile: () => calls.add('update'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ExhaustedDeckView.note), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('View Again'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Update Profile'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.tap(find.text('View Again'));
    await tester.tap(find.text('Browse'));
    await tester.tap(find.text('Update Profile'));
    await tester.pump();

    expect(calls, ['explore', 'view', 'browse', 'update']);
  });

  testWidgets('setup variant shows only explore and update profile', (
    tester,
  ) async {
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: ExhaustedDeckView(
            message:
                'Complete your profile setup so we can find Pals for you. '
                'Add a role and at least one skill.',
            showViewAgain: false,
            showBrowse: false,
            onExplore: () => calls.add('explore'),
            onViewAgain: () => calls.add('view'),
            onUpdateProfile: () => calls.add('update'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Complete your profile setup'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Update Profile'), findsOneWidget);
    expect(find.text('View Again'), findsNothing);
    expect(find.text('Browse'), findsNothing);

    await tester.tap(find.text('Explore'));
    await tester.tap(find.text('Update Profile'));
    await tester.pump();
    expect(calls, ['explore', 'update']);
  });

  testWidgets('exhausted deck fits a small phone without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: ExhaustedDeckView(
            onExplore: () {},
            onViewAgain: () {},
            onBrowse: () {},
            onUpdateProfile: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('reduced motion skips the card return animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ExhaustedDeckView(
              onExplore: () {},
              onViewAgain: () {},
              onBrowse: () {},
              onUpdateProfile: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(ExhaustedDeckView.note), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
