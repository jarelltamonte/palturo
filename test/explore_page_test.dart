import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/explore_page.dart';
import 'package:palturo/theme/theme.dart';

List<Map<String, dynamic>> _roots() => const [
  {
    'path': 'agriculture_livelihood',
    'name': 'Agriculture & Livelihood',
    'depth': 1,
  },
  {'path': 'cooking_culinary', 'name': 'Cooking & Culinary', 'depth': 1},
  {'path': 'household_skills', 'name': 'Household Skills', 'depth': 1},
  {'path': 'language_writing', 'name': 'Language & Writing', 'depth': 1},
  {'path': 'martial_arts', 'name': 'Martial Arts', 'depth': 1},
  {'path': 'modern_practical_skills', 'name': 'Modern Practical', 'depth': 1},
  {'path': 'performing_arts', 'name': 'Performing Arts', 'depth': 1},
  {'path': 'traditional_crafts', 'name': 'Traditional Crafts', 'depth': 1},
  {'path': 'visual_arts_design', 'name': 'Visual Arts & Design', 'depth': 1},
];

Future<int> _count(String path, {required String kind}) async => 3;

Widget _app({
  required ThemeData theme,
  Future<List<Map<String, dynamic>>> Function()? skillsLoader,
  Size? surface,
  double textScale = 1,
  DateTime? now,
  Future<int> Function(String path, {required String kind})? countLoader,
  Future<Map<String, ({int total, int fresh, int newcomers})>> Function(
    String kind,
  )?
  domainCountsLoader,
}) {
  final size = surface ?? const Size(390, 844);
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: ExplorePage(
        taxonomyLoader: () async => _roots(),
        countLoader:
            countLoader ?? (domainCountsLoader == null ? _count : null),
        domainCountsLoader: domainCountsLoader,
        skillsLoader: skillsLoader,
        now: () => now ?? _today,
      ),
    ),
  );
}

final _today = DateTime(2026, 11, 17);

void main() {
  test('featured domain is stable within a day and rotates the next day', () {
    final roots = _roots();
    final first = featuredDomainForDay(roots, _today);
    final again = featuredDomainForDay(roots, _today);
    final tomorrow = featuredDomainForDay(
      roots,
      _today.add(const Duration(days: 1)),
    );

    expect(first, isNotNull);
    expect(again?['path'], first?['path']);
    expect(tomorrow?['path'], isNot(first?['path']));
  });

  test('featured domain visits every domain over a full cycle', () {
    final roots = _roots();
    final seen = <String>{};
    for (var i = 0; i < roots.length; i++) {
      final node = featuredDomainForDay(roots, _today.add(Duration(days: i)));
      seen.add((node?['path'] ?? '').toString());
    }
    expect(seen.length, roots.length);
    expect(featuredDomainForDay(const [], _today), isNull);
  });

  testWidgets('field guide shows the header, feature, and domain cards', (
    tester,
  ) async {
    await tester.pumpWidget(_app(theme: lightMode));
    await tester.pumpAndSettle();

    final featured = featuredDomainForDay(_roots(), _today)!;

    expect(find.text('Browse'), findsOneWidget);
    expect(
      find.text('Follow a craft, meet the person behind it.'),
      findsOneWidget,
    );
    expect(find.text('Search domains'), findsOneWidget);
    expect(find.text('FEATURED'), findsOneWidget);
    // The feature card owns one domain, so the grid lists the rest.
    expect(find.text('MORE DOMAINS'), findsOneWidget);
    expect(find.text('ALL DOMAINS'), findsNothing);
    // Domain numbers are gone from both the section label and the cards.
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d{2}$').hasMatch(w.data ?? ''),
      ),
      findsNothing,
    );
    expect(find.text((featured['name'] ?? '').toString()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty domains stay listed with a no-one-yet label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        theme: lightMode,
        surface: const Size(390, 1600),
        countLoader:
            (path, {required kind}) async => path == 'martial_arts' ? 0 : 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Martial Arts'), findsOneWidget);
    expect(find.text('No mentors yet'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards show the domain total and how many are new', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        theme: lightMode,
        surface: const Size(390, 1600),
        domainCountsLoader:
            (kind) async => {
              'agriculture_livelihood': (total: 0, fresh: 0, newcomers: 0),
              'cooking_culinary': (total: 4, fresh: 2, newcomers: 2),
              'household_skills': (total: 3, fresh: 0, newcomers: 0),
              'language_writing': (total: 1, fresh: 1, newcomers: 0),
              'martial_arts': (total: 0, fresh: 0, newcomers: 0),
              'modern_practical_skills': (total: 2, fresh: 2, newcomers: 1),
              'performing_arts': (total: 2, fresh: 1, newcomers: 0),
              'traditional_crafts': (total: 6, fresh: 6, newcomers: 0),
              'visual_arts_design': (total: 0, fresh: 0, newcomers: 0),
            },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 mentors · 2 new'), findsOneWidget);
    expect(find.text('3 mentors'), findsOneWidget);
    expect(find.text('1 mentor'), findsOneWidget);
    expect(find.text('2 mentors · 1 new'), findsOneWidget);
    expect(find.text('No mentors yet'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters the domain cards', (tester) async {
    await tester.pumpWidget(_app(theme: lightMode));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'cook');
    await tester.pumpAndSettle();

    expect(find.text('RESULTS'), findsOneWidget);
    expect(find.text('Cooking & Culinary'), findsOneWidget);
    expect(find.text('Agriculture & Livelihood'), findsNothing);
    expect(find.text('FEATURED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mentor mode highlights teaching domains and keeps the rest', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        theme: lightMode,
        surface: const Size(390, 1600),
        skillsLoader:
            () async => [
              {
                'kind': 'teach',
                'path': 'cooking_culinary.filipino_cooking',
                'name': 'Filipino Cooking',
              },
            ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mentor'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR TEACHING DOMAINS'), findsOneWidget);
    expect(find.text('Cooking & Culinary'), findsOneWidget);
    expect(find.text('Filipino Cooking'), findsOneWidget);
    expect(find.text('YOU TEACH HERE'), findsOneWidget);
    // The rest of the directory stays available below the teaching card.
    expect(find.text('EXPLORE OTHER DOMAINS'), findsOneWidget);
    expect(find.text('Household Skills'), findsOneWidget);
    expect(find.text('FEATURED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mentor mode without skills points at the profile editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(theme: lightMode, skillsLoader: () async => const []),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mentor'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("haven't added any mentor skills"),
      findsOneWidget,
    );
    expect(find.text('Update your teaching skills'), findsOneWidget);
    expect(find.text('FEATURED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('domain descriptions stay visible at 1.3x text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(theme: lightMode, surface: const Size(360, 640), textScale: 1.3),
    );
    await tester.pumpAndSettle();

    final description = find.text('Recipes, flavors, and kitchen traditions');
    expect(description, findsOneWidget);
    expect(tester.getSize(description).height, greaterThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('field guide fits 360 at 200% text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        theme: lightMode,
        surface: const Size(360, 1400),
        textScale: 2,
        domainCountsLoader:
            (kind) async => {
              for (final node in _roots())
                (node['path'] as String): (total: 25, fresh: 12, newcomers: 12),
            },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Browse'), findsOneWidget);
    final description = find.text('Recipes, flavors, and kitchen traditions');
    expect(description, findsOneWidget);
    expect(tester.getSize(description).height, greaterThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mentor cards fit 360 at 200% text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        theme: lightMode,
        surface: const Size(360, 1600),
        textScale: 2,
        skillsLoader:
            () async => [
              {
                'kind': 'teach',
                'path': 'cooking_culinary.filipino_cooking',
                'name': 'Filipino Cooking',
              },
              {
                'kind': 'teach',
                'path': 'cooking_culinary.filipino_dessert_making',
                'name': 'Filipino Dessert Making',
              },
            ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mentor'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR TEACHING DOMAINS'), findsOneWidget);
    expect(find.text('Filipino Cooking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop width lays the domain grid out in four columns', (
    tester,
  ) async {
    // 1120 matches the desktop shell's content column.
    await tester.binding.setSurfaceSize(const Size(1120, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(theme: lightMode, surface: const Size(1120, 900)),
    );
    await tester.pumpAndSettle();

    final featuredPath =
        (featuredDomainForDay(_roots(), _today)!['path'] ?? '').toString();
    final grid =
        _roots()
            .where((node) => (node['path'] ?? '').toString() != featuredPath)
            .toList();
    final firstRow =
        grid
            .take(4)
            .map((node) => find.text((node['name'] ?? '').toString()))
            .toList();
    for (final card in firstRow) {
      expect(card, findsOneWidget);
    }
    final top = tester.getTopLeft(firstRow.first).dy;
    for (final card in firstRow.skip(1)) {
      expect(tester.getTopLeft(card).dy, top);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode renders the same field guide', (tester) async {
    await tester.pumpWidget(_app(theme: darkMode));
    await tester.pumpAndSettle();

    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('FEATURED'), findsOneWidget);
    expect(find.text('Cooking & Culinary'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
