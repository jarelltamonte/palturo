import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_flow.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/home_page.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/app_banner.dart';
import 'package:palturo/widgets/swipe_deck.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PreferencesService.instance.init();
    AppBannerController.instance.clear();
  });

  tearDown(AppBannerController.instance.clear);

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
    AppBannerController.instance.clear();
  });

  testWidgets('For You does not show the mentor setup reminder', (
    tester,
  ) async {
    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.teach,
      teachingSkillIds: const ['barong_embroidery'],
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

    expect(find.text('Mentor setup'), findsNothing);
    AppBannerController.instance.clear();
  });

  testWidgets('a flagged note shows the red reminder on For You', (
    tester,
  ) async {
    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.learn,
      learningSkillIds: const ['cooking'],
      learningNotes: const {'cooking': 'I want to learn adobo.'},
      noteReviewStatus: const {'learn|cooking': 'rejected'},
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

    expect(find.text('A note needs attention'), findsOneWidget);
    expect(find.text('Update your flagged note.'), findsOneWidget);
    expect(
      AppBannerController.instance.current.value?.title,
      'A note needs attention',
    );
    AppBannerController.instance.clear();
  });

  testWidgets('a mentor gets a login reminder', (tester) async {
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

    expect(AppBannerController.instance.current.value?.title, 'Add a showcase');
    expect(
      AppBannerController.instance.current.value?.body,
      contains('Add a showcase and a note to each teaching skill'),
    );
    AppBannerController.instance.clear();
  });

  testWidgets('a pending teaching skill gets a review nudge', (tester) async {
    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.teach,
      teachingSkillIds: const ['custom_pending_skill'],
      approvedTeachingSkills: const {},
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

    expect(
      AppBannerController.instance.current.value?.title,
      'Mentor setup in review',
    );
    expect(
      AppBannerController.instance.current.value?.body,
      contains('still being reviewed'),
    );
    AppBannerController.instance.clear();
  });

  testWidgets('a pending teaching note gets a review nudge', (tester) async {
    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.teach,
      teachingSkillIds: const ['barong_embroidery'],
      approvedTeachingSkills: const {'barong_embroidery'},
      teachingNotes: const {'barong_embroidery': 'Hands-on and patient.'},
      teachingNoteApproved: const {'barong_embroidery': false},
      noteReviewStatus: const {'teach|barong_embroidery': 'pending'},
      teachingSkillImages: const {'barong_embroidery': 'https://x.test/a.jpg'},
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

    expect(
      AppBannerController.instance.current.value?.title,
      'Mentor notes in review',
    );
    AppBannerController.instance.clear();
  });

  testWidgets('the recommendation filter only offers roles', (tester) async {
    const person = Person(
      id: 'p1',
      name: 'Test Pal',
      schedule: 'Weekends',
      language: 'English',
      learningStyle: 'Hands-on Practice',
      skillName: 'Cooking',
      role: PersonRole.mentor,
    );
    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.learn,
      learningSkillIds: const ['cooking'],
      learningNotes: const {'cooking': 'I want to learn adobo.'},
      notesLoaded: true,
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
          deckLoader: ({bool force = false}) async => const [person],
          seenLoader: () async => <String>{},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Show'), findsOneWidget);
    expect(find.text('Learners'), findsOneWidget);
    expect(find.text('Skill'), findsNothing);
    expect(find.text('All skills'), findsNothing);
  });

  testWidgets('a flagged note blocks the deck swipe with a fix popup', (
    tester,
  ) async {
    const person = Person(
      id: 'p1',
      name: 'Test Pal',
      schedule: 'Weekends',
      language: 'English',
      learningStyle: 'Hands-on Practice',
      skillName: 'Cooking',
      role: PersonRole.mentor,
    );
    final profile = ProfileData(
      schedule: 'Not set',
      role: OnboardingRole.learn,
      learningSkillIds: const ['cooking'],
      learningNotes: const {'cooking': 'I want to learn adobo.'},
      noteReviewStatus: const {'learn|cooking': 'rejected'},
      notesLoaded: true,
      hasCompletedOnboarding: true,
      languages: const ['English'],
      availableDays: const ['Friday'],
    );
    var sent = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: HomePage(
          profileLoader: () async => profile,
          deckLoader: ({bool force = false}) async => const [person],
          seenLoader: () async => <String>{},
          sendRequest: (
            id, {
            String? skillName,
            String? skillPath,
            String? source,
          }) async {
            sent++;
            return 'c1';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SwipeDeck), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(sent, 0);
    expect(find.text('Fix your note first'), findsOneWidget);
    expect(find.text('Fix note'), findsOneWidget);
    AppBannerController.instance.clear();
  });
}
