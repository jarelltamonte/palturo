import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/home_page.dart';
import 'package:palturo/services/match_api.dart';

Person _person({String skillNote = 'Specific skill note'}) {
  return Person(
    id: 'p1',
    name: 'Aling Rosa',
    schedule: 'Mon/Fri',
    language: 'Tagalog',
    learningStyle: 'Discussion',
    skillName: 'Barong Embroidery',
    role: PersonRole.mentor,
    bio: 'Profile bio that should not be used on For You.',
    skillNote: skillNote,
    photoUrls: const [null],
  );
}

Widget _card(
  Person person, {
  VoidCallback? onOpenProfile,
  bool showActions = false,
  VoidCallback? onAdd,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 390,
        height: 844,
        child: PersonCardOverlay(
          person: person,
          showActions: showActions,
          onAdd: onAdd,
          showMenu: false,
          showShadow: false,
          showSkillNote: true,
          onOpenProfile: onOpenProfile,
        ),
      ),
    ),
  );
}

void main() {
  test('mentor mapping uses the teaching skill note', () {
    final person = MatchApi.personFromPublicProfileMap({
      'p_name': 'Aling Rosa',
      'p_role': 'mentor',
      'p_bio': 'Profile bio',
      'p_languages': 'Tagalog',
      'p_styles': 'Discussion',
      'p_availability': <dynamic>[],
      'p_teaching': [
        {
          'skill': 'Barong Embroidery',
          'path': 'arts_design.barong_embroidery',
          'note': 'Teaching note',
        },
      ],
      'p_learning': [
        {
          'skill': 'Cooking Adobo',
          'path': 'everyday_skills.cooking_adobo',
          'note': 'Learning note',
        },
      ],
      'p_showcases': <dynamic>[],
    }, 'p1');

    expect(person.skillName, 'Barong Embroidery');
    expect(person.skillNote, 'Teaching note');
  });

  test('learner mapping uses the learning skill note', () {
    final person = MatchApi.personFromPublicProfileMap({
      'p_name': 'Aling Rosa',
      'p_role': 'learner',
      'p_bio': 'Profile bio',
      'p_languages': 'Tagalog',
      'p_styles': 'Discussion',
      'p_availability': <dynamic>[],
      'p_teaching': [
        {
          'skill': 'Barong Embroidery',
          'path': 'arts_design.barong_embroidery',
          'note': 'Teaching note',
        },
      ],
      'p_learning': [
        {
          'skill': 'Cooking Adobo',
          'path': 'everyday_skills.cooking_adobo',
          'note': 'Learning note',
        },
      ],
      'p_showcases': <dynamic>[],
    }, 'p1');

    expect(person.skillName, 'Cooking Adobo');
    expect(person.skillNote, 'Learning note');
  });

  test('both mapping follows the deck role', () {
    final profile = <String, dynamic>{
      'p_name': 'Aling Rosa',
      'p_role': 'both',
      'p_bio': 'Profile bio',
      'p_languages': 'Tagalog',
      'p_styles': 'Discussion',
      'p_availability': <dynamic>[],
      'p_teaching': [
        {
          'skill': 'Barong Embroidery',
          'path': 'arts_design.barong_embroidery',
          'note': 'Teaching note',
        },
      ],
      'p_learning': [
        {
          'skill': 'Cooking Adobo',
          'path': 'everyday_skills.cooking_adobo',
          'note': 'Learning note',
        },
      ],
      'p_showcases': <dynamic>[],
    };

    final learner = MatchApi.personFromPublicProfileMap(
      profile,
      'p1',
      preferRole: 'learner',
    );
    expect(learner.skillName, 'Cooking Adobo');
    expect(learner.skillNote, 'Learning note');
    expect(learner.role, PersonRole.learner);

    final mentor = MatchApi.personFromPublicProfileMap(
      profile,
      'p1',
      preferRole: 'mentor',
    );
    expect(mentor.skillName, 'Barong Embroidery');
    expect(mentor.skillNote, 'Teaching note');
    expect(mentor.role, PersonRole.mentor);
  });

  test('card mapping shows the skill that actually matched', () {
    final profile = <String, dynamic>{
      'p_name': 'Aling Rosa',
      'p_role': 'both',
      'p_bio': 'Profile bio',
      'p_languages': 'Tagalog',
      'p_styles': 'Discussion',
      'p_availability': <dynamic>[],
      'p_teaching': [
        {
          'skill': 'Barong Embroidery',
          'path': 'arts_design.barong_embroidery',
          'note': 'Teaching note',
        },
        {
          'skill': 'Traditional Music',
          'path': 'music.traditional',
          'note': 'Music note',
        },
      ],
      'p_learning': <dynamic>[],
      'p_showcases': <dynamic>[],
    };

    final person = MatchApi.personFromPublicProfileMap(
      profile,
      'p1',
      preferRole: 'mentor',
      preferSkillId: 'music.traditional',
    );

    expect(person.skillName, 'Traditional Music');
    expect(person.skillNote, 'Music note');
    expect(person.skillKind, 'teach');
  });

  test('showcase media follows the card skill', () {
    final profile = <String, dynamic>{
      'p_name': 'RJ',
      'p_role': 'both',
      'p_bio': 'Bio',
      'p_languages': 'English',
      'p_styles': 'Discussion',
      'p_availability': <dynamic>[],
      'p_teaching': [
        {
          'skill': 'Programming',
          'path': 'modern_practical_skills.programming',
          'note': 'I code.',
        },
        {
          'skill': 'Graphic Design',
          'path': 'modern_practical_skills.graphic_design',
          'note': 'I design.',
        },
      ],
      'p_learning': [
        {
          'skill': 'Filipino Cooking',
          'path': 'cooking_culinary.filipino_cooking',
          'note': 'I want to cook.',
        },
      ],
      'p_showcases': [
        {
          'media': 'https://cdn.example.com/web-dev.jpg',
          'kind': 'image',
          'skill': 'Programming',
          'skill_path': 'modern_practical_skills.programming',
        },
      ],
    };

    // A learning card never shows teaching media.
    final learnCard = MatchApi.personFromPublicProfileMap(
      profile,
      'rj',
      preferRole: 'learner',
      preferSkillId: 'cooking_culinary.filipino_cooking',
      skillKind: 'learn',
    );
    expect(learnCard.skillName, 'Filipino Cooking');
    expect(learnCard.showcaseUrls, isEmpty);
    expect(learnCard.cardMedia.whereType<String>(), isEmpty);

    // The teaching card for the media's own skill keeps it.
    final matchingCard = MatchApi.personFromPublicProfileMap(
      profile,
      'rj',
      preferRole: 'mentor',
      preferSkillId: 'modern_practical_skills.programming',
      skillKind: 'teach',
    );
    expect(matchingCard.showcaseUrls, [
      'https://cdn.example.com/web-dev.jpg',
    ]);

    // A different teaching skill does not inherit it.
    final otherSkillCard = MatchApi.personFromPublicProfileMap(
      profile,
      'rj',
      preferRole: 'mentor',
      preferSkillId: 'modern_practical_skills.graphic_design',
      skillKind: 'teach',
    );
    expect(otherSkillCard.skillName, 'Graphic Design');
    expect(otherSkillCard.showcaseUrls, isEmpty);
  });

  test('card kind overrides the profile role for the displayed side', () {
    final profile = <String, dynamic>{
      'p_name': 'Aling Rosa',
      'p_role': 'mentor',
      'p_bio': 'Profile bio',
      'p_languages': 'Tagalog',
      'p_styles': 'Discussion',
      'p_availability': <dynamic>[],
      'p_teaching': [
        {
          'skill': 'Barong Embroidery',
          'path': 'arts_design.barong_embroidery',
          'note': 'Teaching note',
        },
      ],
      'p_learning': [
        {
          'skill': 'Traditional Music',
          'path': 'music.traditional',
          'note': 'Music note',
        },
      ],
      'p_showcases': <dynamic>[],
    };

    final person = MatchApi.personFromPublicProfileMap(
      profile,
      'p1',
      preferRole: 'mentor',
      preferSkillId: 'music.traditional',
      skillKind: 'learn',
    );

    expect(person.role, PersonRole.learner);
    expect(person.skillName, 'Traditional Music');
    expect(person.skillKind, 'learn');
  });

  test('cards from one person keep distinct deck keys', () {
    Person card(String? cardId) => Person(
      id: 'p1',
      name: 'Aling Rosa',
      schedule: 'Mon/Fri',
      language: 'Tagalog',
      learningStyle: 'Discussion',
      skillName: 'Barong Embroidery',
      role: PersonRole.mentor,
      cardId: cardId,
    );

    expect(deckKeyFor(card('c1')), 'c1');
    expect(deckKeyFor(card('c2')), 'c2');
    expect(deckKeyFor(card('c1')) == deckKeyFor(card('c2')), isFalse);
    expect(deckKeyFor(card(null)), 'p1');
  });

  testWidgets('For You card shows skill note, not bio', (tester) async {
    await tester.pumpWidget(_card(_person()));

    expect(find.text('Specific skill note'), findsOneWidget);
    expect(
      find.text('Profile bio that should not be used on For You.'),
      findsNothing,
    );
    expect(find.text('View profile'), findsNothing);
  });

  testWidgets('card tap opens profile even without the pill', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _card(_person(), onOpenProfile: () => opened = true),
    );

    await tester.tap(find.text('Aling Rosa'));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('card action still wins over the profile tap layer', (
    tester,
  ) async {
    var opened = false;
    var added = false;
    await tester.pumpWidget(
      _card(
        _person(),
        onOpenProfile: () => opened = true,
        showActions: true,
        onAdd: () => added = true,
      ),
    );

    await tester.tap(find.text('Send request'));
    await tester.pump();

    expect(added, isTrue);
    expect(opened, isFalse);
  });

  testWidgets('missing skill note hides body instead of falling back to bio', (
    tester,
  ) async {
    await tester.pumpWidget(_card(_person(skillNote: '')));

    expect(
      find.text('Profile bio that should not be used on For You.'),
      findsNothing,
    );
  });
}
