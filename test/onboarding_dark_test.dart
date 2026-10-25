import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding_intro.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/theme.dart';

void main() {
  testWidgets('dark onboarding keeps inactive dots visible', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: darkMode, home: const OnboardingIntro()),
    );
    await tester.pump();
    final context = tester.element(find.byType(OnboardingIntro));

    final dots =
        tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .where(
              (dot) =>
                  dot.constraints?.maxWidth == 8 ||
                  dot.constraints?.maxWidth == 18,
            )
            .toList();
    expect(dots, hasLength(3));

    final inactive = dots.where((dot) => dot.constraints?.maxWidth == 8).first;
    final active = dots.where((dot) => dot.constraints?.maxWidth == 18).first;
    expect(
      (inactive.decoration as BoxDecoration).color,
      AppColors.mutedText(context).withValues(alpha: 0.55),
    );
    final surface = Theme.of(context).colorScheme.surface;
    final inactiveColor = (inactive.decoration as BoxDecoration).color!;
    final activeColor = (active.decoration as BoxDecoration).color!;
    expect(
      _contrast(Color.alphaBlend(inactiveColor, surface), surface),
      greaterThanOrEqualTo(3.0),
    );
    expect(activeColor, AppColors.primary);
    expect(
      _contrast(Color.alphaBlend(activeColor, surface), surface),
      greaterThanOrEqualTo(3.0),
    );
    expect(inactiveColor, isNot(AppColors.textSecondary));
  });

  testWidgets('light onboarding keeps the original inactive dot color', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const OnboardingIntro()),
    );
    await tester.pump();
    final inactive =
        tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .where((dot) => dot.constraints?.maxWidth == 8)
            .first;
    expect(
      (inactive.decoration as BoxDecoration).color,
      AppColors.textSecondary,
    );
  });
}

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}
