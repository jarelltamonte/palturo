import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/skills_card.dart';
import 'package:palturo/theme/theme.dart';

void main() {
  testWidgets('a new skill row starts empty with a Choose a skill hint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SkillsCard.toLearn(isEditing: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Choose a skill'), findsOneWidget);
    // No popular-skill list should appear before the user types.
    expect(find.text('Cooking Pinakbet'), findsNothing);
    expect(find.text('Baybayin Script'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing filters the suggestions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SkillsCard.toLearn(isEditing: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'filipino');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Filipino Mains'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
