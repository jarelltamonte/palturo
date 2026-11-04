import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
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
          showProfilePill: false,
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

    expect(person.skillName, 'barong embroidery');
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

    expect(person.skillName, 'cooking adobo');
    expect(person.skillNote, 'Learning note');
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
