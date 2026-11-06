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
          ..setAvailabilityDays({'Friday'});

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
    expect(find.text('Cooking Pinakbet'), findsOneWidget);
    expect(find.text('Barong Embroidery'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hands-on Practice'), 300);
    expect(find.text('Hands-on Practice'), findsOneWidget);

    expect(find.text('Edit'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Save and continue'));
    expect(saved, 1);
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
        'Add your role, availability, language, and learning style to save.',
      ),
      findsOneWidget,
    );
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Save and continue'),
    );
    expect(button.onPressed, isNull);
  });
}
