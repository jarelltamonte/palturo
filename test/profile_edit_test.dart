import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_edit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  ProfileData profile() => ProfileData(
    id: 'profile-1',
    name: 'Alex Example',
    schedule: 'Fri/Weekends',
    availableDays: const ['Friday', 'Saturday', 'Sunday'],
    bio: 'Original bio',
    languages: const ['English'],
    interests: const ['Visual Demonstration'],
    role: OnboardingRole.both,
    learningSkillIds: const ['other:Learning skill:arts_design'],
    teachingSkillIds: const ['other:Teaching skill:everyday_skills'],
  );

  Future<void> pumpEdit(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: ProfileEditPage(profile: profile()),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextButton saveButton(WidgetTester tester) => tester.widget<TextButton>(
    find.ancestor(of: find.text('Save'), matching: find.byType(TextButton)),
  );

  testWidgets('bio edit enables Save and shows the dirty marker', (
    tester,
  ) async {
    await pumpEdit(tester);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Updated bio');
    await tester.pump();

    expect(saveButton(tester).onPressed, isNotNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Unsaved changes',
      ),
      findsOneWidget,
    );
  });

  testWidgets('discard dialog uses explicit keep/discard actions', (
    tester,
  ) async {
    await pumpEdit(tester);
    await tester.enterText(find.byType(TextField).first, 'Updated bio');
    await tester.pump();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Your edits have not been saved.'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('core controls survive 200% text scale', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpEdit(tester);
    expect(find.text('PROFILE PHOTOS'), findsOneWidget);
    expect(find.textContaining('Changing role hides skills'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role change preview keeps hidden skill counts', (tester) async {
    await pumpEdit(tester);

    final teachRole = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('I want to\nteach'),
    );
    await tester.ensureVisible(teachRole);
    await tester.tap(teachRole);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preview profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile preview'), findsOneWidget);
    expect(find.text('1 selected'), findsNWidgets(2));
    expect(find.text('Mentor'), findsOneWidget);
  });
}
