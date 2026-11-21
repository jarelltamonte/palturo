import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_controller.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/screens/onboarding_review_screen.dart';
import 'package:palturo/theme/theme.dart';

void main() {
  testWidgets('review shows every section and exposes edit/save actions', (
    tester,
  ) async {
    final controller =
        OnboardingController()
          ..role = OnboardingRole.both
          ..learningInterests.add('cooking_pinakbet')
          ..teachingInterests.add('barong_embroidery')
          ..learningStyles.add('Hands-on Practice')
          ..languages.add('English')
          ..setAvailabilityDays({'Friday'})
          ..learningNotes['cooking_pinakbet'] =
              'I want to cook adobo and sinigang for my family.';

    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: OnboardingReviewScreen(
          controller: controller,
          stepLabel: 'Step 5 of 5 - Review',
          onSave: () => saved++,
          onEditRole: () {},
          onEditLearning: () {},
          onEditTeaching: () {},
          onEditDetails: () {},
        ),
      ),
    );

    expect(find.text('Review your profile'), findsOneWidget);
    expect(find.text('Step 5 of 5 - Review'), findsOneWidget);
    expect(find.text('Learner and mentor'), findsOneWidget);
    expect(find.text('Showcase required for visibility'), findsOneWidget);
    for (
      var i = 0;
      i < 8 && find.text('Cooking Pinakbet').evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
    }
    expect(find.text('Cooking Pinakbet'), findsOneWidget);
    for (
      var i = 0;
      i < 8 && find.text('Barong Embroidery').evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
    }
    expect(find.text('Barong Embroidery'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hands-on Practice'), 300);
    expect(find.text('Hands-on Practice'), findsOneWidget);

    expect(find.text('Edit'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Save and continue'));
    expect(saved, 1);
  });

  testWidgets('review resolves a custom skill id to its label', (tester) async {
    final controller =
        OnboardingController()
          ..role = OnboardingRole.learn
          ..learningInterests.add('other:onboarding:Quality Assurance')
          ..learningStyles.add('Hands-on Practice')
          ..languages.add('English')
          ..setAvailabilityDays({'Friday'});

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: OnboardingReviewScreen(
          controller: controller,
          onSave: () {},
          onEditRole: () {},
          onEditLearning: () {},
          onEditTeaching: () {},
          onEditDetails: () {},
        ),
      ),
    );

    expect(find.text('Quality Assurance'), findsOneWidget);
    expect(find.textContaining('other:onboarding:'), findsNothing);
  });

  testWidgets('review lists the teaching style only for mentors', (
    tester,
  ) async {
    final mentor =
        OnboardingController()
          ..role = OnboardingRole.teach
          ..teachingInterests.add('barong_embroidery')
          ..learningStyles.add('Hands-on Practice')
          ..teachingStyles.add('Discussion')
          ..languages.add('English')
          ..setAvailabilityDays({'Friday'});

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: OnboardingReviewScreen(
          controller: mentor,
          onSave: () {},
          onEditRole: () {},
          onEditLearning: () {},
          onEditTeaching: () {},
          onEditDetails: () {},
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Teaching style'), 300);
    expect(find.text('Teaching style'), findsOneWidget);
    expect(find.text('Discussion'), findsOneWidget);

    final learner =
        OnboardingController()
          ..role = OnboardingRole.learn
          ..learningInterests.add('cooking_pinakbet')
          ..learningStyles.add('Hands-on Practice')
          ..languages.add('English')
          ..setAvailabilityDays({'Friday'});

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: OnboardingReviewScreen(
          controller: learner,
          onSave: () {},
          onEditRole: () {},
          onEditLearning: () {},
          onEditTeaching: () {},
          onEditDetails: () {},
        ),
      ),
    );
    expect(find.text('Teaching style'), findsNothing);
  });

  testWidgets('review blocks saving an incomplete active role', (tester) async {
    final controller = OnboardingController()..role = OnboardingRole.both;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: OnboardingReviewScreen(
          controller: controller,
          onSave: () {},
          onEditRole: () {},
          onEditLearning: () {},
          onEditTeaching: () {},
          onEditDetails: () {},
        ),
      ),
    );
    expect(
      find.text(
        'Add your role, availability, language, learning style, and a '
        'note for every learning skill to save.',
      ),
      findsOneWidget,
    );
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Save and continue'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('review blocks saving until every learner skill has a note', (
    tester,
  ) async {
    final controller =
        OnboardingController()
          ..role = OnboardingRole.learn
          ..learningInterests.add('cooking_pinakbet')
          ..learningStyles.add('Hands-on Practice')
          ..languages.add('English')
          ..setAvailabilityDays({'Friday'});

    Widget build() => MaterialApp(
      theme: lightMode,
      home: OnboardingReviewScreen(
        controller: controller,
        onSave: () {},
        onEditRole: () {},
        onEditLearning: () {},
        onEditTeaching: () {},
        onEditDetails: () {},
        onEditLearningNote: (_) {},
      ),
    );

    await tester.pumpWidget(build());
    expect(find.text('Add a note about this skill'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save and continue'),
          )
          .onPressed,
      isNull,
    );

    controller.setLearningNote(
      'cooking_pinakbet',
      'I want to cook adobo for my family.',
    );
    await tester.pumpWidget(build());
    await tester.pump();
    expect(find.text('Add a note about this skill'), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save and continue'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
