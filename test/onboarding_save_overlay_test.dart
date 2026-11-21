import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/widgets/onboarding_save_overlay.dart';
import 'package:palturo/theme/theme.dart';

void main() {
  testWidgets('save overlay explains the work before it feels slow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: const Scaffold(body: OnboardingSaveOverlay(slow: false)),
      ),
    );

    expect(find.text(OnboardingSaveOverlay.title), findsOneWidget);
    expect(find.text(OnboardingSaveOverlay.body), findsOneWidget);
    expect(find.text(OnboardingSaveOverlay.slowBody), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('save overlay never inherits fallback underlines', (
    tester,
  ) async {
    // The real overlay sits outside a Scaffold, where an absent Material would
    // otherwise apply Flutter's yellow-underlined fallback text style.
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: const OnboardingSaveOverlay(slow: false),
      ),
    );

    final texts = tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(OnboardingSaveOverlay),
        matching: find.byType(RichText),
      ),
    );
    expect(texts, isNotEmpty);
    for (final text in texts) {
      expect(text.text.style?.decoration, isNot(TextDecoration.underline));
    }
  });

  testWidgets('save overlay reassures once the wait is long', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: const Scaffold(body: OnboardingSaveOverlay(slow: true)),
      ),
    );

    expect(find.text(OnboardingSaveOverlay.title), findsOneWidget);
    expect(find.text(OnboardingSaveOverlay.slowBody), findsOneWidget);
    expect(find.text(OnboardingSaveOverlay.body), findsNothing);
  });

  testWidgets('save overlay fits a small phone at 200% text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(body: OnboardingSaveOverlay(slow: true)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(OnboardingSaveOverlay.slowBody), findsOneWidget);
  });
}
