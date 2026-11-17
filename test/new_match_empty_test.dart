import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/new_match_empty.dart';
import 'package:palturo/widgets/user_avatar.dart';

Person _person({PersonRole role = PersonRole.learner}) => Person(
  id: 'p1',
  name: 'Lolo Ben Cruz',
  schedule: 'Weekends',
  language: 'Filipino, English',
  learningStyle: 'Hands-on Practice',
  skillName: 'Kitchen Basics',
  role: role,
  bio: 'Retired cook from Batangas.',
);

Widget _app({
  Person? person,
  PersonRole? role = PersonRole.learner,
  String? skillName = 'Kitchen Basics',
  ThemeData? theme,
  Size surface = const Size(390, 844),
  double textScale = 1,
  VoidCallback? onOpenProfile,
  ValueChanged<String>? onUseStarter,
  bool sheetVisible = true,
  bool canRestoreSheet = false,
  VoidCallback? onShowSheet,
  VoidCallback? onDismissSheet,
}) {
  return MaterialApp(
    theme: theme ?? lightMode,
    home: MediaQuery(
      data: MediaQueryData(
        size: surface,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: NewMatchEmpty(
          name: 'Lolo Ben Cruz',
          avatarImage: null,
          skillName: skillName,
          role: role,
          person: person,
          onOpenProfile: onOpenProfile ?? () {},
          onUseStarter: onUseStarter ?? (_) {},
          sheetVisible: sheetVisible,
          canRestoreSheet: canRestoreSheet,
          onShowSheet: onShowSheet,
          onDismissSheet: onDismissSheet ?? () {},
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget app, {
  Size surface = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  test('ice breakers use the skill and the peer role', () {
    final learner = buildIceBreakers(
      name: 'Lolo Ben Cruz',
      skillName: 'Kitchen Basics',
      role: PersonRole.learner,
    );
    final mentor = buildIceBreakers(
      name: 'Lolo Ben Cruz',
      skillName: 'Kitchen Basics',
      role: PersonRole.mentor,
    );
    final noSkill = buildIceBreakers(name: 'Lolo Ben Cruz');

    expect(learner.first, contains('Kitchen Basics'));
    expect(learner[1], contains('Lolo'));
    expect(learner[1], contains('learn'));
    expect(mentor[1], contains('teaching'));
    expect(noSkill.first, isNot(contains('Kitchen Basics')));
    expect(learner.length, 3);
  });

  testWidgets('new match shows the profile, preferences, and starters', (
    tester,
  ) async {
    await _pump(tester, _app(person: _person()));

    expect(find.text('Lolo Ben Cruz'), findsOneWidget);
    expect(find.text('You matched on'), findsOneWidget);
    expect(find.text('Kitchen Basics'), findsOneWidget);
    // Preferences sit below the matched skill.
    expect(find.text('Weekends'), findsOneWidget);
    expect(find.text('Filipino, English'), findsOneWidget);
    expect(find.text('Hands-on Practice'), findsOneWidget);

    expect(find.text('Start the conversation'), findsOneWidget);
    expect(
      find.text(
        buildIceBreakers(
          name: 'Lolo Ben Cruz',
          skillName: 'Kitchen Basics',
        ).first,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a starter fills the composer through the callback', (
    tester,
  ) async {
    String? used;
    await _pump(
      tester,
      _app(person: _person(), onUseStarter: (text) => used = text),
    );

    await tester.tap(find.byTooltip('Use this starter').first);
    await tester.pump();

    expect(
      used,
      buildIceBreakers(
        name: 'Lolo Ben Cruz',
        skillName: 'Kitchen Basics',
      ).first,
    );
  });

  testWidgets('shuffle rotates the starters', (tester) async {
    final starters = buildIceBreakers(
      name: 'Lolo Ben Cruz',
      skillName: 'Kitchen Basics',
    );
    String? used;
    await _pump(
      tester,
      _app(person: _person(), onUseStarter: (text) => used = text),
    );

    await tester.tap(find.text('Shuffle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use this starter').first);
    await tester.pump();

    expect(used, starters[1]);
  });

  testWidgets('the sheet can be dismissed and restored', (tester) async {
    var dismissed = false;
    await _pump(
      tester,
      StatefulBuilder(
        builder:
            (context, setLocal) => _app(
              person: _person(),
              sheetVisible: !dismissed,
              canRestoreSheet: dismissed,
              onDismissSheet: () => setLocal(() => dismissed = true),
              onShowSheet: () => setLocal(() => dismissed = false),
            ),
      ),
    );

    await tester.tap(find.byTooltip('Hide starter suggestions'));
    await tester.pumpAndSettle();

    expect(find.text('Start the conversation'), findsNothing);
    expect(find.text('Lolo Ben Cruz'), findsOneWidget);
    expect(find.text('Kitchen Basics'), findsOneWidget);

    await tester.tap(find.text('Show starters'));
    await tester.pumpAndSettle();

    expect(find.text('Start the conversation'), findsOneWidget);
  });

  testWidgets('the avatar opens the profile', (tester) async {
    var opened = 0;
    await _pump(tester, _app(person: _person(), onOpenProfile: () => opened++));

    await tester.tap(find.byType(UserAvatar));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('dots follow the starter scroll', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester, _app(person: _person()));

      expect(find.bySemanticsLabel('Starter 1 of 3'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('starter-scroll')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Starter 3 of 3'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('without a person there are no preference chips', (tester) async {
    await _pump(tester, _app(person: null));

    expect(find.text('Lolo Ben Cruz'), findsOneWidget);
    expect(find.text('Weekends'), findsNothing);
    expect(find.text('Start the conversation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new match fits 360 at 200% text', (tester) async {
    await _pump(
      tester,
      _app(person: _person(), surface: const Size(360, 640), textScale: 2),
      surface: const Size(360, 640),
    );

    expect(find.text('Lolo Ben Cruz'), findsOneWidget);
    expect(find.text('Start the conversation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new match renders in dark mode', (tester) async {
    await _pump(tester, _app(person: _person(), theme: darkMode));

    expect(find.text('Start the conversation'), findsOneWidget);
    expect(find.byTooltip('Use this starter'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
