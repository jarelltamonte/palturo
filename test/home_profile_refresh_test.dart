import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/home_page.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/theme/theme.dart';

const _person = Person(
  id: 'p1',
  name: 'Test Pal',
  schedule: 'Weekends',
  language: 'English',
  learningStyle: 'Hands-on Practice',
  skillName: 'Cooking',
  role: PersonRole.mentor,
);

ProfileData _profile({
  String bio = 'I cook.',
  int? age = 30,
  String? gender = 'female',
  String name = 'Test User',
  String? avatarUrl = 'https://example.com/a.jpg',
  List<String> learning = const ['cooking'],
  List<String> teaching = const [],
  List<String> languages = const ['English'],
  List<String> interests = const ['Hands-on Practice'],
  List<String> teachingStyles = const [],
  List<String> availableDays = const ['mon', 'wed'],
  Map<String, String> learningNotes = const {'cooking': 'I cook daily.'},
  Map<String, String> teachingNotes = const {},
  Map<String, String> teachingSkillImages = const {},
  bool notesLoaded = true,
}) {
  return ProfileData(
    schedule: 'Mon, Wed',
    firstName: name,
    bio: bio,
    age: age,
    gender: gender,
    avatarUrl: avatarUrl,
    learningSkillIds: learning,
    teachingSkillIds: teaching,
    languages: languages,
    interests: interests,
    teachingStyles: teachingStyles,
    availableDays: availableDays,
    learningNotes: learningNotes,
    teachingNotes: teachingNotes,
    teachingSkillImages: teachingSkillImages,
    notesLoaded: notesLoaded,
  );
}

void main() {
  group('matchInputsChanged', () {
    test('ignores cosmetic edits', () {
      final before = _profile();
      expect(
        ProfileService.matchInputsChanged(before, _profile(bio: 'New bio.')),
        isFalse,
      );
      expect(
        ProfileService.matchInputsChanged(before, _profile(age: 41)),
        isFalse,
      );
      expect(
        ProfileService.matchInputsChanged(before, _profile(gender: 'male')),
        isFalse,
      );
      expect(
        ProfileService.matchInputsChanged(before, _profile(name: 'Renamed')),
        isFalse,
      );
      expect(
        ProfileService.matchInputsChanged(
          before,
          _profile(avatarUrl: 'https://example.com/b.jpg'),
        ),
        isFalse,
      );
      expect(
        ProfileService.matchInputsChanged(
          before,
          _profile(teachingSkillImages: const {'cooking': 'https://x/y.jpg'}),
        ),
        isFalse,
      );
    });

    test('detects every input the matcher reads', () {
      final before = _profile();
      expect(
        ProfileService.matchInputsChanged(
          before,
          _profile(learning: const ['cooking', 'sewing']),
        ),
        isTrue,
        reason: 'added skill',
      );
      expect(
        ProfileService.matchInputsChanged(before, _profile(teaching: ['sewing'])),
        isTrue,
        reason: 'new teaching side',
      );
      expect(
        ProfileService.matchInputsChanged(
          before,
          _profile(languages: const ['English', 'Filipino']),
        ),
        isTrue,
        reason: 'language',
      );
      expect(
        ProfileService.matchInputsChanged(
          before,
          _profile(interests: const ['Reading']),
        ),
        isTrue,
        reason: 'learning style',
      );
      expect(
        ProfileService.matchInputsChanged(
          before,
          _profile(availableDays: const ['tue']),
        ),
        isTrue,
        reason: 'availability',
      );
      expect(
        ProfileService.matchInputsChanged(
          before,
          _profile(learningNotes: const {'cooking': 'I cook weekly.'}),
        ),
        isTrue,
        reason: 'note text feeds the query embedding',
      );
    });

    test('a failed notes read does not look like an edit', () {
      final before = _profile(notesLoaded: false);
      expect(
        ProfileService.matchInputsChanged(
          before,
          _profile(notesLoaded: false, learningNotes: const {}),
        ),
        isFalse,
      );
    });

    test('an unknown previous profile counts as a match change', () {
      expect(ProfileService.matchInputsChanged(null, _profile()), isTrue);
    });
  });

  group('For You deck rebuild', () {
    late int revision;
    late int matchRevision;

    setUp(() {
      revision = ProfileService.profileRevision.value;
      matchRevision = ProfileService.matchInputsRevision.value;
    });

    tearDown(() {
      ProfileService.profileRevision.value = revision;
      ProfileService.matchInputsRevision.value = matchRevision;
    });

    testWidgets('a cosmetic profile edit does not reload the deck', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: HomePage(
            deckLoader: ({bool force = false}) {
              calls++;
              return Future<List<Person>>.value(const [_person]);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);

      ProfileService.profileRevision.value = revision + 1;
      await tester.pump(kDeckProfileNoticeDelay + const Duration(milliseconds: 20));

      expect(calls, 1);
      expect(find.text(kDeckProfileMessage), findsNothing);
    });

    testWidgets('a matching edit explains the rebuild over an existing deck', (
      tester,
    ) async {
      final rebuild = Completer<List<Person>>();
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: HomePage(
            deckLoader: ({bool force = false}) {
              calls++;
              return calls == 1
                  ? Future<List<Person>>.value(const [_person])
                  : rebuild.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(kDeckProfileMessage), findsNothing);

      ProfileService.matchInputsRevision.value = matchRevision + 1;
      await tester.pump();

      // The old deck stays usable while the rebuild runs.
      expect(find.text('Test Pal'), findsOneWidget);
      // The notice is deferred, so a fast rebuild never flashes it.
      expect(find.text(kDeckProfileMessage), findsNothing);

      await tester.pump(
        kDeckProfileNoticeDelay + const Duration(milliseconds: 20),
      );
      expect(find.text(kDeckProfileMessage), findsOneWidget);

      rebuild.complete(const [_person]);
      await tester.pumpAndSettle();

      expect(find.text(kDeckProfileMessage), findsNothing);
      expect(find.text('Test Pal'), findsOneWidget);
    });

    testWidgets('an empty deck uses the same copy while it rebuilds', (
      tester,
    ) async {
      final rebuild = Completer<List<Person>>();
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: HomePage(
            deckLoader: ({bool force = false}) {
              calls++;
              return calls == 1
                  ? Future<List<Person>>.value(const <Person>[])
                  : rebuild.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      ProfileService.matchInputsRevision.value = matchRevision + 1;
      await tester.pump();

      expect(find.text(kDeckProfileMessage), findsOneWidget);
      expect(find.text(kDeckSlowMessage), findsNothing);

      rebuild.complete(const <Person>[]);
      await tester.pumpAndSettle();

      expect(find.text(kDeckProfileMessage), findsNothing);
    });
  });
}
