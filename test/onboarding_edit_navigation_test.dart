import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_controller.dart';
import 'package:palturo/onboarding/onboarding_flow.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PreferencesService.instance.init();

    final draft =
        OnboardingController()
          ..role = OnboardingRole.both
          ..learningInterests.add('fishing')
          ..learningNotes['fishing'] = 'I want to learn how to catch';
    await PreferencesService.instance.setString(
      'onboarding_draft',
      jsonEncode(draft.toJson()),
    );
  });

  Future<void> pumpFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: OnboardingFlow(onFinished: () {})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('back from an edit step follows the onboarding sequence', (
    tester,
  ) async {
    await pumpFlow(tester);
    expect(find.text('Review your profile'), findsOneWidget);

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    expect(find.text('What describes\nyou best?'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('personalize'), findsOneWidget);
    expect(find.text('Review your profile'), findsNothing);
  });

  testWidgets('continue from an edit step returns to review', (tester) async {
    await pumpFlow(tester);
    expect(find.text('Review your profile'), findsOneWidget);

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    expect(find.text('What describes\nyou best?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Review your profile'), findsOneWidget);
  });
}
