import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_flow.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/card/person_card.dart';
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

  testWidgets('a mentor without notes sees the setup reminder', (tester) async {
    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.teach,
      teachingSkillIds: const ['barong_embroidery'],
      approvedTeachingSkills: const {'barong_embroidery'},
      teachingNotes: const {},
      notesLoaded: true,
      hasCompletedOnboarding: true,
      languages: const ['English'],
      availableDays: const ['Friday'],
    );

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

    expect(find.text('Mentor setup'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Showcase + notes'), findsAtLeastNWidgets(1));
  });

  testWidgets('a ready mentor does not see the setup reminder', (tester) async {
    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.teach,
      teachingSkillIds: const ['barong_embroidery'],
      approvedTeachingSkills: const {'barong_embroidery'},
      teachingNotes: const {'barong_embroidery': 'Hands-on and patient.'},
      teachingNoteApproved: const {'barong_embroidery': true},
      notesLoaded: true,
      teachingSkillImages: const {'barong_embroidery': 'https://x.test/a.jpg'},
      hasCompletedOnboarding: true,
      isProfileCompleted: true,
      languages: const ['English'],
      availableDays: const ['Friday'],
    );

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

    expect(find.text('Mentor setup'), findsNothing);
  });

  testWidgets('a mentor with a note under review sees the pending copy', (
    tester,
  ) async {
    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.teach,
      teachingSkillIds: const ['barong_embroidery'],
      approvedTeachingSkills: const {'barong_embroidery'},
      teachingNotes: const {'barong_embroidery': 'Hands-on and patient.'},
      teachingNoteApproved: const {'barong_embroidery': false},
      notesLoaded: true,
      teachingSkillImages: const {'barong_embroidery': 'https://x.test/a.jpg'},
      hasCompletedOnboarding: true,
      languages: const ['English'],
      availableDays: const ['Friday'],
    );

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

    expect(find.text('Notes in review'), findsAtLeastNWidgets(1));
  });

  testWidgets('a pending teaching skill shows the skill-review copy', (
    tester,
  ) async {
    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.teach,
      teachingSkillIds: const ['custom_pending_skill'],
      teachingNotes: const {},
      notesLoaded: true,
      hasCompletedOnboarding: true,
      languages: const ['English'],
      availableDays: const ['Friday'],
    );

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

    expect(find.text('Skill in review'), findsAtLeastNWidgets(1));
  });

  testWidgets('the mentor reminder fits a narrow 200% viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.teach,
      teachingSkillIds: const ['barong_embroidery'],
      approvedTeachingSkills: const {'barong_embroidery'},
      teachingNotes: const {},
      notesLoaded: true,
      hasCompletedOnboarding: true,
      languages: const ['English'],
      availableDays: const ['Friday'],
    );
    final never = Completer<List<Person>>();

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: HomePage(
            profileLoader: () async => profile,
            deckLoader: ({bool force = false}) => never.future,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Mentor setup'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);

    final title = tester.renderObject<RenderParagraph>(
      find.text('Mentor setup').first,
    );
    final body = tester.renderObject<RenderParagraph>(
      find.text('Showcase + notes').first,
    );
    expect(title.didExceedMaxLines, isFalse);
    expect(body.didExceedMaxLines, isFalse);
  });
}
