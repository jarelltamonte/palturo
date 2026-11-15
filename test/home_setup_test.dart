import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_flow.dart';
import 'package:palturo/screen/home_page.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PreferencesService.instance.init();
  });

  testWidgets('setup checklist offers Finish Profile', (tester) async {
    final profile = ProfileData(schedule: 'Not set');

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: HomePage(
          profileLoader: () async => profile,
          deckLoader: ({bool force = false}) async => const [],
          seenLoader: () async => <String>{},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finish Profile'), findsOneWidget);
    expect(find.text('Update Profile'), findsNothing);
    expect(find.textContaining('Complete your profile setup'), findsOneWidget);

    await tester.tap(find.text('Finish Profile'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The button resumes onboarding instead of opening the profile editor.
    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.text('Update Profile'), findsNothing);
  });
}
