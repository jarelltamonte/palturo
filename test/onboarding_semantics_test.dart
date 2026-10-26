import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/widgets/chip_selector.dart';
import 'package:palturo/onboarding/widgets/onboarding_scaffold.dart';
import 'package:palturo/onboarding/widgets/role_card_group.dart';
import 'package:palturo/theme/theme.dart';

void main() {
  testWidgets('step label and chip selection semantics are exposed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: OnboardingScaffold(
          title: 'Skills',
          stepLabel: 'Step 2 of 4 - Learning skills',
          child: ChipSelector(
            options: const [
              OnboardingOption('a', 'Cooking Pinakbet'),
              OnboardingOption('b', 'Baybayin Script'),
            ],
            selected: const {'a'},
            maxSelections: 1,
            onToggle: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Step 2 of 4 - Learning skills'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Cooking Pinakbet')),
      matchesSemantics(
        label: 'Cooking Pinakbet',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Baybayin Script')),
      matchesSemantics(
        label: 'Baybayin Script',
        isButton: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
  });

  testWidgets('role cards and onboarding back expose selected/44px semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: OnboardingScaffold(
          title: 'Role',
          stepLabel: 'Step 1 of 4 - Role',
          showBackButton: true,
          onBack: () {},
          child: RoleCardGroup(
            options: const [
              RoleOption(
                OnboardingRole.learn,
                'assets/icons/rlearner.svg',
                'I want to\nlearn',
              ),
              RoleOption(
                OnboardingRole.teach,
                'assets/icons/rmentor.svg',
                'I want to\nteach',
              ),
            ],
            selected: OnboardingRole.learn,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('I want to learn')),
      matchesSemantics(
        label: 'I want to learn',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    final back = tester.getSize(find.byTooltip('Back'));
    expect(back.width, greaterThanOrEqualTo(44));
    expect(back.height, greaterThanOrEqualTo(44));
  });
}
