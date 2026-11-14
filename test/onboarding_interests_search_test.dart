import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/screens/onboarding_interests_screen.dart';
import 'package:palturo/onboarding/skill_options.dart';
import 'package:palturo/theme/theme.dart';

const _options = [
  OnboardingOption('farming', 'Farming'),
  OnboardingOption('programming', 'Programming'),
  OnboardingOption('filipino_cooking', 'Filipino Cooking'),
  OnboardingOption('others', 'Others'),
];

Widget _host({
  required Set<String> selected,
  required ValueChanged<String> onToggle,
  ValueChanged<String>? onCreate,
  int maxSelections = 3,
}) {
  return MaterialApp(
    theme: lightMode,
    home: OnboardingInterestsScreen(
      highlightWord: 'Learning?',
      options: _options,
      selected: selected,
      maxSelections: maxSelections,
      onToggle: onToggle,
      onCreate: onCreate,
      progress: 0.4,
      onContinue: () {},
    ),
  );
}

void main() {
  testWidgets('search filters the depth-2 chips', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(selected: {}, onToggle: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Farming'), findsOneWidget);
    expect(find.text('Programming'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'prog');
    await tester.pumpAndSettle();

    expect(find.text('Programming'), findsOneWidget);
    expect(find.text('Farming'), findsNothing);
    expect(find.text('Filipino Cooking'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a novel query offers a create chip', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final created = <String>[];
    await tester.pumpWidget(
      _host(selected: {}, onToggle: (_) {}, onCreate: created.add),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Sourdough Baking');
    await tester.pumpAndSettle();

    expect(find.text('Create "Sourdough Baking"'), findsOneWidget);
    await tester.tap(find.text('Create "Sourdough Baking"'));
    await tester.pumpAndSettle();

    expect(created, ['Sourdough Baking']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected chips stay visible while searching', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(selected: const {'farming'}, onToggle: (_) {}),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'prog');
    await tester.pumpAndSettle();

    expect(find.text('Farming'), findsOneWidget);
    expect(find.text('Programming'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create is hidden at the selection limit', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        selected: const {'farming', 'programming', 'filipino_cooking'},
        onToggle: (_) {},
        onCreate: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Sourdough');
    await tester.pumpAndSettle();

    expect(find.text('Create "Sourdough"'), findsNothing);
    expect(find.text('Remove a skill to add another.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists every selectable depth-2 skill', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: OnboardingInterestsScreen(
          highlightWord: 'Learning?',
          options: kSelectableSkills,
          selected: const {},
          maxSelections: 3,
          onToggle: (_) {},
          onCreate: (_) {},
          progress: 0.4,
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final option in kSelectableSkills) {
      expect(
        find.text(option.label),
        findsOneWidget,
        reason: '${option.label} is missing from onboarding',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
