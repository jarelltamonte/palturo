import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_controller.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/screens/onboarding_note_screen.dart';
import 'package:palturo/theme/theme.dart';

Widget _app({
  String initial = '',
  ValueChanged<String>? onChanged,
  VoidCallback? onContinue,
  Size size = const Size(390, 844),
  double textScale = 1,
}) {
  return MaterialApp(
    theme: lightMode,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: OnboardingNoteScreen(
        skillLabel: 'Filipino Cooking',
        initialNote: initial,
        onChanged: onChanged ?? (_) {},
        onContinue: onContinue ?? () {},
        onBack: () {},
        progress: 0.4,
      ),
    ),
  );
}

void main() {
  testWidgets('asks about the selected skill and blocks short notes', (
    tester,
  ) async {
    var text = '';
    var continued = 0;
    await tester.pumpWidget(
      _app(onChanged: (value) => text = value, onContinue: () => continued++),
    );

    expect(
      find.textContaining(
        'Tell us more about what you want to learn about Filipino Cooking',
      ),
      findsOneWidget,
    );
    expect(find.text('Add at least 10 characters.'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue'),
    );
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'short');
    await tester.pump();
    expect(text, 'short');
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Continue'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byType(TextField),
      'I want to cook adobo and sinigang for my family.',
    );
    await tester.pump();
    expect(find.textContaining('Looks good'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pump();
    expect(continued, 1);
  });

  testWidgets('restores an existing note and fits 200% text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        initial: 'I want to learn regional dishes.',
        size: const Size(360, 640),
        textScale: 2,
      ),
    );

    await tester.scrollUntilVisible(
      find.byType(TextField),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(TextField), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'I want to learn regional dishes.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a note at the shared minimum length can continue', (
    tester,
  ) async {
    var continued = 0;
    await tester.pumpWidget(_app(onContinue: () => continued++));

    await tester.enterText(
      find.byType(TextField),
      'a' * (kOnboardingNoteMinLength - 1),
    );
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Continue'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byType(TextField),
      'a' * kOnboardingNoteMinLength,
    );
    await tester.pump();
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue'),
    );
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    expect(continued, 1);
  });

  testWidgets('notes round-trip through the controller and gate completion', (
    tester,
  ) async {
    final controller =
        OnboardingController()
          ..role = OnboardingRole.learn
          ..learningInterests.addAll({'cooking_adobo', 'cooking_sinigang'});

    expect(controller.hasAllLearningNotes, isFalse);
    controller.setLearningNote('cooking_adobo', 'I want to cook adobo.');
    expect(controller.hasAllLearningNotes, isFalse);
    controller.setLearningNote('cooking_sinigang', 'I want to cook sinigang.');
    expect(controller.hasAllLearningNotes, isTrue);

    final restored = OnboardingController()..applyJson(controller.toJson());
    expect(restored.learningNotes['cooking_adobo'], 'I want to cook adobo.');
    expect(restored.hasAllLearningNotes, isTrue);
  });
}
