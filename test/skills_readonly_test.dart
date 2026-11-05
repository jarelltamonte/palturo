import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/skills_card.dart';
import 'package:palturo/theme/theme.dart';

void main() {
  testWidgets('read-only skills render as summary rows, not fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SkillsCard.toLearn(
              isEditing: false,
              initialSkillIds: ['cooking_pinakbet'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cooking Pinakbet'), findsOneWidget);
    expect(find.text('Everyday Practical Skills'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty read-only skills show an add action', (tester) async {
    var added = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: SkillsCard.toLearn(
            isEditing: false,
            initialSkillIds: const [],
            onAddSkills: () => added++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No skills added yet'), findsOneWidget);
    await tester.tap(find.text('Add skills'));
    expect(added, 1);
    expect(tester.takeException(), isNull);
  });
}
