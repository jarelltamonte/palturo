import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_edit.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/profile_completion_card.dart';
import 'package:palturo/widgets/top_labeled_field.dart';
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

class _CapturingProfileService implements ProfileService {
  ProfileData? captured;

  @override
  Future<ProfileData> updateProfile(
    ProfileData updatedProfile, {
    List<String?>? newPhotoLocalPaths,
    Map<String, String>? teachingSkillImages,
    void Function(String skillName)? onClassifyingSkill,
  }) async {
    captured = updatedProfile;
    return updatedProfile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HoldProfileService implements ProfileService {
  final Completer<ProfileData> completer = Completer<ProfileData>();

  @override
  Future<ProfileData> updateProfile(
    ProfileData updatedProfile, {
    List<String?>? newPhotoLocalPaths,
    Map<String, String>? teachingSkillImages,
    void Function(String skillName)? onClassifyingSkill,
  }) => completer.future;

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
    learningNotes: const {
      'other:Learning skill:arts_design': 'I want to learn design.',
    },
    teachingNotes: const {
      'other:Teaching skill:everyday_skills':
          'I can teach practical everyday skills.',
    },
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
    expect(slots, hasLength(1));
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
    expect(addIcons, hasLength(1));
    for (final icon in addIcons) {
      expect(icon.color, AppColors.mutedText(context));
    }
  });

  testWidgets('core controls survive 200% text scale', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpEdit(tester);
    expect(find.text('PROFILE PHOTOS'), findsOneWidget);
    expect(
      find.textContaining('Your role updates with your skills'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected skill is removed from the form with an error prompt', (
    tester,
  ) async {
    const rejectedId = 'other:Teaching skill:everyday_skills';
    await pumpEdit(
      tester,
      service: const _RejectingProfileService(
        RejectedSkill(skillId: rejectedId, name: 'Thawing Ice', kind: 'teach'),
      ),
    );
    // `other:<categoryId>:<name>` is how custom rows are encoded.
    expect(find.text('everyday_skills'), findsOneWidget);

    // Make the draft dirty so Save is enabled.
    await tester.enterText(find.byType(TextField).first, 'Updated bio');
    await tester.pump();
    await tester.tap(find.text('Save').first);
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
    await tester.tap(find.text('Save').first);
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

  testWidgets('save overlay rotates reassuring progress copy', (tester) async {
    final service = _HoldProfileService();
    await pumpEdit(tester, service: service);

    final bioField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is TopLabeledField && widget.label == 'Introduce yourself',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(bioField, 'Updated bio');
    await tester.pump();

    await tester.tap(find.text('Save').first);
    await tester.pump();
    expect(find.text('Saving your profile...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Preparing your card and notes...'), findsOneWidget);

    service.completer.complete(profile().copyWith(bio: 'Updated bio'));
    await tester.pumpAndSettle();
  });

  testWidgets('saving without a skill note prompts but does not block', (
    tester,
  ) async {
    final service = _CapturingProfileService();
    await pumpEdit(
      tester,
      service: service,
      data: profile().copyWith(teachingNotes: const {}),
    );

    final bioField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is TopLabeledField && widget.label == 'Introduce yourself',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(bioField, 'Updated bio');
    await tester.pump();

    await tester.ensureVisible(find.text('Save').first);
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(find.text('A few details are missing'), findsOneWidget);
    expect(find.textContaining('Add a note for'), findsOneWidget);

    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();

    expect(service.captured, isNotNull);
    expect(service.captured?.teachingNotes, isEmpty);
  });

  testWidgets('saving without a learner note is blocked', (tester) async {
    final service = _CapturingProfileService();
    await pumpEdit(
      tester,
      service: service,
      data: profile().copyWith(learningNotes: const {}, notesLoaded: true),
    );

    final bioField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is TopLabeledField && widget.label == 'Introduce yourself',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(bioField, 'Updated bio');
    await tester.pump();

    await tester.ensureVisible(find.text('Save').first);
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(find.text('Learning notes required'), findsOneWidget);
    expect(find.textContaining('before saving'), findsOneWidget);
    expect(find.text('Save anyway'), findsNothing);

    await tester.tap(find.text('Review notes'));
    await tester.pumpAndSettle();

    expect(service.captured, isNull);
  });

  testWidgets('a flagged learner note is highlighted and clears when edited', (
    tester,
  ) async {
    await pumpEdit(
      tester,
      data: profile().copyWith(
        noteReviewStatus: const {
          'learn|other:Learning skill:arts_design': 'rejected',
        },
      ),
    );

    await tester.scrollUntilVisible(
      find.textContaining('Tell us more about what you want to learn'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('FLAGGED — UPDATE TO PUBLISH'), findsOneWidget);
    expect(find.text('Update note'), findsOneWidget);
    expect(find.textContaining('This note was flagged'), findsOneWidget);

    final noteField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is TopLabeledField && widget.label == 'Update note',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(noteField, 'I want to learn layout and color.');
    await tester.pump();

    expect(find.text('FLAGGED — UPDATE TO PUBLISH'), findsNothing);
    expect(find.textContaining('This note was flagged'), findsNothing);
  });

  testWidgets('private age and gender save with the profile', (tester) async {
    final service = _CapturingProfileService();
    await pumpEdit(tester, service: service);

    final ageField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is TopLabeledField && widget.label == 'Age',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(ageField, '29');
    await tester.pump();

    await tester.ensureVisible(find.text('Gender').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gender').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Woman'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save').first);
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(service.captured?.age, 29);
    expect(service.captured?.gender, 'woman');
  });

  testWidgets('an under-18 age blocks saving with a popup', (tester) async {
    final service = _CapturingProfileService();
    await pumpEdit(tester, service: service);

    final ageField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is TopLabeledField && widget.label == 'Age',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(ageField, '17');
    await tester.pump();

    expect(find.text('Enter an age between 13 and 120.'), findsNothing);
    await tester.ensureVisible(find.text('Save').first);
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(find.text('Check your age'), findsOneWidget);
    expect(find.textContaining('18 and older'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(service.captured, isNull);
  });

  testWidgets('an over-120 age blocks saving with a popup', (tester) async {
    final service = _CapturingProfileService();
    await pumpEdit(tester, service: service);

    final ageField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is TopLabeledField && widget.label == 'Age',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(ageField, '130');
    await tester.pump();

    await tester.ensureVisible(find.text('Save').first);
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(find.text('Check your age'), findsOneWidget);
    expect(find.textContaining('120 or less'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(service.captured, isNull);
  });

  testWidgets('the completion card carries the showcase requirement', (
    tester,
  ) async {
    await pumpEdit(
      tester,
      data: profile().copyWith(teachingSkillImages: const {}),
    );
    expect(find.text('Showcase'), findsOneWidget);
    expect(find.textContaining('learners can find you'), findsOneWidget);
  });

  testWidgets('the completion card drops showcase once media exists', (
    tester,
  ) async {
    await pumpEdit(tester);
    expect(find.text('Showcase'), findsNothing);
  });

  testWidgets('teaching profile prompts but can save without a showcase', (
    tester,
  ) async {
    final service = _SlowProfileService();
    await pumpEdit(
      tester,
      service: service,
      data: profile().copyWith(teachingSkillImages: const {}),
    );

    final bioField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is TopLabeledField && widget.label == 'Introduce yourself',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(bioField, 'Updated bio');
    await tester.pump();
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    // The reminder names the discovery cost, but it is not a hard block.
    expect(find.text('A few details are missing'), findsOneWidget);
    expect(
      find.textContaining('learners can find you in Browse and For You'),
      findsWidgets,
    );

    await tester.tap(find.text('Save anyway'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('A few details are missing'), findsNothing);
    expect(find.textContaining('to PalTuro'), findsOneWidget);
    expect(service.completer.isCompleted, isFalse);
  });

  testWidgets('showcase reminder keeps the editor open to add media', (
    tester,
  ) async {
    final service = _SlowProfileService();
    await pumpEdit(
      tester,
      service: service,
      data: profile().copyWith(teachingSkillImages: const {}),
    );

    final bioField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is TopLabeledField && widget.label == 'Introduce yourself',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(bioField, 'Updated bio');
    await tester.pump();
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('A few details are missing'), findsNothing);
    expect(find.text('Edit Profile'), findsOneWidget);
    // The save never started.
    expect(service.completer.isCompleted, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving derives the mentor role from a teaching skill', (
    tester,
  ) async {
    final service = _CapturingProfileService();
    await pumpEdit(
      tester,
      service: service,
      data: profile().copyWith(
        role: OnboardingRole.learn,
        learningSkillIds: const [],
        learningNotes: const {},
      ),
    );

    final bioField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is TopLabeledField && widget.label == 'Introduce yourself',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(bioField, 'Updated bio');
    await tester.pump();
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(service.captured?.role, OnboardingRole.teach);
    expect(service.captured?.teachingSkillIds, isNotEmpty);
    expect(service.captured?.learningSkillIds, isEmpty);
  });

  testWidgets('completion card tracks draft edits live', (tester) async {
    await pumpEdit(tester);

    String percent() {
      final text = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(ProfileCompletionCard),
              matching: find.textContaining('%'),
            )
            .first,
      );
      return text.data ?? '';
    }

    final before = percent();
    final bioField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is TopLabeledField && widget.label == 'Introduce yourself',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(bioField, '');
    await tester.pump();

    expect(percent(), isNot(before));
  });

  testWidgets('preview shows the role derived from the selected skills', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.byTooltip('Preview profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile preview'), findsOneWidget);
    expect(find.text('1 selected'), findsNWidgets(2));
    expect(find.text('Learner & Mentor'), findsOneWidget);
  });
}
