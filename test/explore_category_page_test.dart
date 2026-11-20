import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/explore_category_page.dart';
import 'package:palturo/screen/explore_taxonomy.dart';
import 'package:palturo/theme/theme.dart';

List<Map<String, dynamic>> _taxonomy(String path) => const [
  {
    'path': 'cooking_culinary',
    'name': 'Cooking & Culinary',
    'depth': 1,
    'usage_count': 6,
  },
  {
    'path': 'cooking_culinary.filipino',
    'name': 'Filipino cooking',
    'depth': 2,
    'usage_count': 3,
  },
  {
    'path': 'cooking_culinary.baking',
    'name': 'Baking & pastry',
    'depth': 2,
    'usage_count': 2,
  },
  {
    'path': 'cooking_culinary.regional',
    'name': 'Regional cuisine',
    'depth': 2,
    'usage_count': 1,
  },
  {
    'path': 'cooking_culinary.quiet',
    'name': 'Quiet skill',
    'depth': 2,
    'usage_count': 0,
  },
];

Person _person(int index) => Person(
  id: 'p$index',
  name: 'Person $index',
  schedule: 'Weekends',
  language: 'Filipino',
  learningStyle: 'Hands-on',
  skillName: 'Cooking',
  role: PersonRole.mentor,
);

class _FakeUsers {
  _FakeUsers({
    this.rootTeach = 6,
    this.rootLearn = 2,
    this.noPeople = false,
    this.failPaths = const {},
  });

  final int rootTeach;
  final int rootLearn;
  final bool noPeople;
  final Set<String> failPaths;
  final List<String> kinds = [];

  Future<List<Person>> call(String path, {required String kind}) async {
    kinds.add('$path:$kind');
    if (failPaths.contains(path)) throw Exception('boom');
    if (noPeople && kind == 'teach') return const [];
    switch (path) {
      case 'cooking_culinary':
        final count = kind == 'teach' ? rootTeach : rootLearn;
        return [for (var i = 0; i < count; i++) _person(i)];
      case 'cooking_culinary.filipino':
        return kind == 'teach' ? [_person(0), _person(1)] : [_person(0)];
      case 'cooking_culinary.baking':
        return kind == 'teach' ? [_person(2)] : const [];
      case 'cooking_culinary.regional':
        return kind == 'teach' ? [_person(3)] : const [];
      default:
        return const [];
    }
  }
}

Widget _app({
  required ThemeData theme,
  required Future<List<Person>> Function(String path, {required String kind})
  users,
  Size? surface,
  double textScale = 1,
  bool mentor = false,
  String nodePath = 'cooking_culinary',
  String nodeLabel = 'Cooking & Culinary',
  Set<String> teachingPaths = const <String>{},
  List<BrowseCrumb> ancestors = const <BrowseCrumb>[],
  String nodeKind = 'category',
  int nodeDepth = 1,
  List<Map<String, dynamic>> Function(String path)? taxonomy,
  Future<({int total, int fresh, int newcomers})> Function(
    String path, {
    required String kind,
  })?
  countsLoader,
}) {
  final size = surface ?? const Size(390, 844);
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: ExploreCategoryPage(
        key: ValueKey('$nodePath|$nodeDepth|${ancestors.length}'),
        nodePath: nodePath,
        nodeLabel: nodeLabel,
        description: 'Recipes, flavors, and kitchen traditions',
        mentor: mentor,
        teachingPaths: teachingPaths,
        ancestors: ancestors,
        nodeKind: nodeKind,
        nodeDepth: nodeDepth,
        taxonomyLoader: (path) async => (taxonomy ?? _taxonomy)(path),
        usersLoader: users,
        countsLoader: countsLoader,
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ThemeData theme,
  required Future<List<Person>> Function(String path, {required String kind})
  users,
  Size surface = const Size(390, 844),
  double textScale = 1,
  bool mentor = false,
  String nodePath = 'cooking_culinary',
  String nodeLabel = 'Cooking & Culinary',
  Set<String> teachingPaths = const <String>{},
  List<BrowseCrumb> ancestors = const <BrowseCrumb>[],
  String nodeKind = 'category',
  int nodeDepth = 1,
  List<Map<String, dynamic>> Function(String path)? taxonomy,
  Future<({int total, int fresh, int newcomers})> Function(
    String path, {
    required String kind,
  })?
  countsLoader,
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(
      theme: theme,
      users: users,
      surface: surface,
      textScale: textScale,
      mentor: mentor,
      nodePath: nodePath,
      nodeLabel: nodeLabel,
      teachingPaths: teachingPaths,
      ancestors: ancestors,
      nodeKind: nodeKind,
      nodeDepth: nodeDepth,
      taxonomy: taxonomy,
      countsLoader: countsLoader,
    ),
  );
  await tester.pumpAndSettle();
}

List<Map<String, dynamic>> _programmingTaxonomy(String path) => const [
  {
    'path': 'modern_practical_skills',
    'name': 'Modern Practical Skills',
    'kind': 'category',
    'depth': 1,
    'usage_count': 2,
  },
  {
    'path': 'modern_practical_skills.programming',
    'name': 'Programming',
    'kind': 'category',
    'depth': 2,
    'usage_count': 2,
  },
  {
    'path': 'modern_practical_skills.programming.general_programming',
    'name': 'General Programming',
    'kind': 'skill',
    'depth': 3,
    'usage_count': 1,
  },
  {
    'path': 'modern_practical_skills.programming.python_programming',
    'name': 'Python Programming',
    'kind': 'skill',
    'depth': 3,
    'usage_count': 1,
  },
];

Future<List<Person>> _programmingUsers(
  String path, {
  required String kind,
}) async {
  if (path.endsWith('general_programming') ||
      path.endsWith('python_programming')) {
    return [_person(0)];
  }
  return const [];
}

void main() {
  testWidgets('domain page shows the hero, counts, skills, and one action', (
    tester,
  ) async {
    final users = _FakeUsers();
    await _pump(tester, theme: lightMode, users: users.call);

    expect(find.text('Cooking & Culinary'), findsOneWidget);
    expect(
      find.text('Recipes, flavors, and kitchen traditions'),
      findsOneWidget,
    );
    expect(find.text('6'), findsOneWidget);
    expect(find.text('mentors here'), findsOneWidget);
    expect(find.text('2 learners here'), findsOneWidget);

    expect(find.text('SKILLS'), findsOneWidget);
    expect(find.text('Filipino cooking'), findsOneWidget);
    expect(find.text('2 mentors'), findsOneWidget);
    expect(find.text('Baking & pastry'), findsOneWidget);
    expect(find.text('1 mentor'), findsNWidgets(2));
    // Skills with nobody in the active role stay hidden.
    expect(find.text('Quiet skill'), findsNothing);

    expect(find.text('Start browsing mentors'), findsOneWidget);
    expect(
      find.text('Swipe through 6 mentors, no pressure to match'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single available person reads as singular', (tester) async {
    final users = _FakeUsers(rootTeach: 1);
    await _pump(tester, theme: lightMode, users: users.call);

    expect(find.text('mentor here'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty domain keeps the skills and drops the deck action', (
    tester,
  ) async {
    final users = _FakeUsers(rootTeach: 0, rootLearn: 2, noPeople: true);
    await _pump(tester, theme: lightMode, users: users.call);

    expect(
      find.textContaining('No mentors are free in this domain right now'),
      findsOneWidget,
    );
    expect(find.text('SKILLS'), findsOneWidget);
    expect(find.text('Filipino cooking'), findsOneWidget);
    expect(find.text('Start browsing mentors'), findsNothing);
    // Role switching lives on Browse, so the domain page offers no swap.
    expect(find.text('Switch to teaching'), findsNothing);
    expect(find.textContaining('switch roles'), findsNothing);
    // The empty state still offers a retry.
    expect(find.text('Check again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an all-matched domain explains the missing people', (
    tester,
  ) async {
    final users = _FakeUsers(noPeople: true);
    await _pump(
      tester,
      theme: lightMode,
      users: users.call,
      countsLoader:
          (path, {required kind}) async => (total: 3, fresh: 0, newcomers: 0),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('mentors here'), findsOneWidget);
    expect(
      find.textContaining('Matched with 3 mentors in this domain'),
      findsOneWidget,
    );
    expect(
      find.textContaining('No new mentors are free right now'),
      findsOneWidget,
    );
    expect(find.text('Start browsing mentors'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the matched panel uses the singular for one person', (
    tester,
  ) async {
    final users = _FakeUsers(noPeople: true);
    await _pump(
      tester,
      theme: lightMode,
      users: users.call,
      countsLoader:
          (path, {required kind}) async => (total: 1, fresh: 0, newcomers: 0),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('mentor here'), findsOneWidget);
    expect(
      find.textContaining('Matched with 1 mentor in this domain'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mentor cannot browse learners outside their teaching skills', (
    tester,
  ) async {
    await _pump(
      tester,
      theme: lightMode,
      users: _FakeUsers().call,
      mentor: true,
      nodePath: 'cooking_culinary.filipino_cooking',
      nodeLabel: 'Filipino Cooking',
      teachingPaths: const {'cooking_culinary.filipino_dessert_making'},
    );

    expect(
      find.textContaining('Add Filipino Cooking to your teaching skills'),
      findsOneWidget,
    );
    expect(find.text('Update teaching skills'), findsOneWidget);
    expect(find.text('Start browsing learners'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mentor can browse learners on a skill they teach', (
    tester,
  ) async {
    await _pump(
      tester,
      theme: lightMode,
      users: _FakeUsers().call,
      mentor: true,
      nodePath: 'cooking_culinary.filipino',
      nodeLabel: 'Filipino cooking',
      teachingPaths: const {'cooking_culinary.filipino'},
    );

    expect(find.text('Start browsing learners'), findsOneWidget);
    expect(find.text('Update teaching skills'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed skill count keeps the row without a number', (
    tester,
  ) async {
    final users = _FakeUsers(failPaths: {'cooking_culinary.baking'});
    await _pump(tester, theme: lightMode, users: users.call);

    expect(find.text('Baking & pastry'), findsOneWidget);
    // Filipino (2) and regional (1) still report; baking does not invent one.
    expect(find.text('1 mentor'), findsOneWidget);
    expect(find.text('2 mentors'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a skill opens its own domain page', (tester) async {
    final users = _FakeUsers();
    await _pump(tester, theme: lightMode, users: users.call);

    await tester.tap(find.text('Filipino cooking'));
    await tester.pumpAndSettle();

    expect(find.text('Filipino cooking'), findsOneWidget);
    expect(
      find.text('Explore Filipino cooking in the PalTuro community.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('domain page renders in dark mode', (tester) async {
    final users = _FakeUsers();
    await _pump(tester, theme: darkMode, users: users.call);

    expect(find.text('Cooking & Culinary'), findsOneWidget);
    expect(find.text('Start browsing mentors'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('domain page fits 360 at 200% text', (tester) async {
    final users = _FakeUsers();
    await _pump(
      tester,
      theme: lightMode,
      users: users.call,
      surface: const Size(360, 1400),
      textScale: 2,
    );

    expect(find.text('Cooking & Culinary'), findsOneWidget);
    expect(find.text('Filipino cooking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout puts the hero and skills in two columns', (
    tester,
  ) async {
    final users = _FakeUsers();
    await _pump(
      tester,
      theme: lightMode,
      users: users.call,
      surface: const Size(1120, 900),
    );

    final heroX = tester.getTopLeft(find.text('mentors here')).dx;
    final skillsX = tester.getTopLeft(find.text('Filipino cooking')).dx;
    expect(skillsX, greaterThan(heroX + 200));
    expect(find.text('Start browsing mentors'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('domain, category, and skill pages read as different levels', (
    tester,
  ) async {
    await _pump(
      tester,
      theme: lightMode,
      users: _programmingUsers,
      nodePath: 'modern_practical_skills',
      nodeLabel: 'Modern Practical Skills',
      nodeDepth: 1,
      nodeKind: 'category',
      taxonomy: _programmingTaxonomy,
    );
    expect(find.text('DOMAIN'), findsOneWidget);
    expect(find.text('SUBCATEGORIES'), findsOneWidget);
    expect(find.text('Part of '), findsNothing);
    expect(find.text('Programming'), findsOneWidget);

    await _pump(
      tester,
      theme: lightMode,
      users: _programmingUsers,
      nodePath: 'modern_practical_skills.programming',
      nodeLabel: 'Programming',
      ancestors: const [
        BrowseCrumb(
          label: 'Modern Practical Skills',
          path: 'modern_practical_skills',
        ),
      ],
      nodeDepth: 2,
      nodeKind: 'category',
      taxonomy: _programmingTaxonomy,
    );
    expect(find.text('CATEGORY'), findsOneWidget);
    expect(find.text('Part of Modern Practical Skills'), findsOneWidget);
    expect(find.text('SKILLS'), findsOneWidget);
    expect(find.text('General Programming'), findsOneWidget);

    await _pump(
      tester,
      theme: lightMode,
      users: _programmingUsers,
      nodePath: 'modern_practical_skills.programming.general_programming',
      nodeLabel: 'General Programming',
      ancestors: const [
        BrowseCrumb(
          label: 'Modern Practical Skills',
          path: 'modern_practical_skills',
        ),
        BrowseCrumb(
          label: 'Programming',
          path: 'modern_practical_skills.programming',
        ),
      ],
      nodeDepth: 3,
      nodeKind: 'skill',
      taxonomy: _programmingTaxonomy,
    );
    expect(find.text('SKILL'), findsOneWidget);
    expect(find.text('Part of Programming'), findsOneWidget);
    expect(find.text('SKILLS'), findsNothing);
    expect(find.text('Start browsing mentors'), findsOneWidget);
    expect(find.text('Modern Practical Skills'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
