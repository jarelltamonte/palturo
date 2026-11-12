import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_edit.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Always rejects the given row, mirroring a `classify-skill` refusal.
class _RejectingProfileService implements ProfileService {
  const _RejectingProfileService(this.rejected);

  final RejectedSkill rejected;

  @override
  Future<ProfileData> updateProfile(
    ProfileData updatedProfile, {
    List<String?>? newPhotoLocalPaths,
    Map<String, String>? teachingSkillImages,
    void Function(String skillName)? onClassifyingSkill,
  }) async {
    throw SkillModerationException.rejected([rejected]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Holds the save open so the progress copy can be asserted.
class _SlowProfileService implements ProfileService {
  final Completer<ProfileData> completer = Completer<ProfileData>();

  @override
  Future<ProfileData> updateProfile(
    ProfileData updatedProfile, {
    List<String?>? newPhotoLocalPaths,
    Map<String, String>? teachingSkillImages,
    void Function(String skillName)? onClassifyingSkill,
  }) {
    onClassifyingSkill?.call('Weaving Sleeping Mat');
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
    teachingSkillImages: const {
      'other:Teaching skill:everyday_skills':
          'https://example.test/showcase.png',
    },
  );

  Future<void> pumpEdit(
    WidgetTester tester, {
    ThemeData? theme,
    ProfileService? service,
    ProfileData? data,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? lightMode,
        home: ProfileEditPage(
          profile: data ?? profile(),
          profileService: service,
        ),
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

  testWidgets('dark empty photo slots use theme surface', (tester) async {
    await pumpEdit(tester, theme: darkMode);
    final context = tester.element(find.byType(ProfileEditPage));
    expect(Theme.of(context).brightness, Brightness.dark);
    final slots =
        tester.widgetList<Container>(find.byType(Container)).where((container) {
          final decoration = container.decoration;
          if (decoration is! BoxDecoration) return false;
          final border = decoration.border;
          return border is Border && border.top.width == 3;
        }).toList();
    expect(slots, hasLength(3));
    for (final slot in slots) {
      final color = (slot.decoration as BoxDecoration).color;
      expect(color, AppColors.mutedSurface(context));
      expect(color, isNot(Colors.white));
    }
    final addIcons =
        tester
            .widgetList<Icon>(find.byIcon(Icons.add))
            .where((icon) => icon.size == 32)
            .toList();
    expect(addIcons, hasLength(3));
    for (final icon in addIcons) {
      expect(icon.color, AppColors.mutedText(context));
    }
  });

  testWidgets('core controls survive 200% text scale', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpEdit(tester);
    expect(find.text('PROFILE PHOTOS'), findsOneWidget);
    expect(find.textContaining('Changing role hides skills'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected skill is removed from the form with an error prompt', (
    tester,
  ) async {
    const rejectedId = 'other:Teaching skill:everyday_skills';
    await pumpEdit(
      tester,
      service: const _RejectingProfileService(
        RejectedSkill(
          skillId: rejectedId,
          name: 'Thawing Ice',
          kind: 'teach',
        ),
      ),
    );
    // `other:<categoryId>:<name>` is how custom rows are encoded.
    expect(find.text('everyday_skills'), findsOneWidget);

    // Make the draft dirty so Save is enabled.
    await tester.enterText(find.byType(TextField).first, 'Updated bio');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Skill not added'), findsOneWidget);
    expect(find.textContaining('Thawing Ice'), findsOneWidget);
    expect(find.text('everyday_skills'), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Skill not added'), findsNothing);
    expect(find.text('everyday_skills'), findsNothing);
  });

  testWidgets('save overlay says when a new skill is being added', (
    tester,
  ) async {
    final service = _SlowProfileService();
    await pumpEdit(tester, service: service);

    await tester.enterText(find.byType(TextField).first, 'Updated bio');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('Weaving Sleeping Mat'), findsOneWidget);
    expect(find.textContaining('30 seconds'), findsOneWidget);
    expect(find.text('Saving profile…'), findsNothing);

    // Fail the save so the page stays mounted and the state is cleaned up.
    service.completer.completeError(Exception('network down'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Weaving Sleeping Mat'), findsNothing);
  });

  testWidgets('teaching profile requires a showcase before saving', (
    tester,
  ) async {
    final service = _SlowProfileService();
    await pumpEdit(
      tester,
      service: service,
      data: profile().copyWith(teachingSkillImages: const {}),
    );

    await tester.enterText(find.byType(TextField).first, 'Updated bio');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Showcase Required'), findsOneWidget);
    expect(service.completer.isCompleted, isFalse);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Showcase Required'), findsNothing);
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
