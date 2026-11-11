import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_controller.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/screens/onboarding_role_screen.dart';
import 'package:palturo/onboarding/widgets/chip_selector.dart';
import 'package:palturo/onboarding/widgets/onboarding_scaffold.dart';
import 'package:palturo/onboarding/widgets/role_card_group.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_spacing.dart';
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

  testWidgets('role cards and onboarding back expose selected/48px semantics', (
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
          scrollBody: true,
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
    expect(back.width, greaterThanOrEqualTo(AppSpacing.iconTarget));
    expect(back.height, greaterThanOrEqualTo(AppSpacing.iconTarget));

    final selected = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.bySemanticsLabel('I want to learn'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final selectedBorder =
        (selected.decoration! as BoxDecoration).border! as Border;
    expect(selectedBorder.top.width, 2);
    expect(selectedBorder.top.color, AppColors.primary);

    final unselected = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.bySemanticsLabel('I want to teach'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final unselectedBorder =
        (unselected.decoration! as BoxDecoration).border! as Border;
    expect(unselectedBorder.top.width, 1);
    final card = tester.getSize(find.bySemanticsLabel('I want to learn'));
    expect(card.height, AppSpacing.onboardingRoleCardHeight);
  });

  testWidgets('role step no longer shows a step label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: OnboardingRoleScreen(
          controller: OnboardingController(),
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 1 of'), findsNothing);
  });

  testWidgets('role cards survive short landscape and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget build(double scale) => MaterialApp(
      theme: lightMode,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
      home: OnboardingScaffold(
        title: 'What describes\nyou best?',
        subtitle: 'Select one that applies',
        stepLabel: 'Step 1 of 4 - Role',
        showBackButton: true,
        onBack: () {},
        onPrimaryPressed: () {},
        scrollBody: true,
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
            RoleOption(
              OnboardingRole.both,
              'assets/icons/rboth.svg',
              'I can do\nboth',
            ),
          ],
          selected: OnboardingRole.learn,
          onSelect: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(build(1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(RoleCardGroup)).height,
      AppSpacing.onboardingRoleCardHeight,
    );

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(build(2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(RoleCardGroup)).height,
      greaterThan(AppSpacing.onboardingRoleCardHeight),
    );

    tester.view.physicalSize = const Size(640, 411);
    await tester.pumpWidget(build(2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final card = tester.getSize(find.byType(RoleCardGroup));
    expect(card.height, greaterThan(0));
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
    final viewport = tester.getRect(find.byType(CustomScrollView));
    final group = tester.getRect(find.byType(RoleCardGroup));
    expect(group.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
  });

  testWidgets('role cards keep a distinct selected border in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: darkMode,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
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
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final selected = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.bySemanticsLabel('I want to learn'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final border = (selected.decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, 2);
    expect(border.top.color, AppColors.primary);
  });
}
