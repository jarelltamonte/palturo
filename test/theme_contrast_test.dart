import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/theme.dart';

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final high = l1 > l2 ? l1 : l2;
  final low = l1 > l2 ? l2 : l1;
  return (high + 0.05) / (low + 0.05);
}

void main() {
  test('light accent text meets WCAG AA on white', () {
    expect(
      _contrast(AppColors.accentTextLight, AppColors.white),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('light muted text meets WCAG AA on white', () {
    expect(
      _contrast(AppColors.mutedTextLight, AppColors.white),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('dark muted text meets WCAG AA on charcoal', () {
    expect(
      _contrast(AppColors.mutedTextDark, AppColors.background),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('lime remains legible as an accent on charcoal', () {
    expect(
      _contrast(AppColors.primary, AppColors.background),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('resolver returns the light foreground tokens', (tester) async {
    late Color accent;
    late Color muted;

    await tester.pumpWidget(MaterialApp(
      theme: lightMode,
      home: Builder(builder: (context) {
        accent = AppColors.accentText(context);
        muted = AppColors.mutedText(context);
        return const SizedBox.shrink();
      }),
    ));

    expect(accent, AppColors.accentTextLight);
    expect(muted, AppColors.mutedTextLight);
  });

  testWidgets('resolver returns the dark foreground tokens', (tester) async {
    late Color accent;
    late Color muted;

    await tester.pumpWidget(MaterialApp(
      theme: darkMode,
      home: Builder(builder: (context) {
        accent = AppColors.accentText(context);
        muted = AppColors.mutedText(context);
        return const SizedBox.shrink();
      }),
    ));

    expect(accent, AppColors.primary);
    expect(muted, AppColors.mutedTextDark);
  });
}
