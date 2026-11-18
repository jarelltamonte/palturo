import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/explore_expand.dart';
import 'package:palturo/theme/theme.dart';

Person _person(
  String id,
  String name, {
  String skill = 'Filipino Cooking',
  String path = 'cooking_culinary.filipino_cooking',
}) => Person(
  id: id,
  name: name,
  schedule: 'Weekends',
  language: 'English',
  learningStyle: 'Hands-on Practice',
  skillName: skill,
  skillPath: path,
  role: PersonRole.mentor,
);

Widget _app({
  required Future<List<Person>> Function(String path, {required String kind})
  users,
  Future<List<Person>> Function({int limit})? random,
  Future<String?> Function(
    String userId, {
    String? skillName,
    String? skillPath,
    String? source,
  })?
  sendRequest,
  Size surface = const Size(390, 844),
  double textScale = 1,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? lightMode,
    home: MediaQuery(
      data: MediaQueryData(
        size: surface,
        textScaler: TextScaler.linear(textScale),
      ),
      child: ExploreExpand(
        nodePath: 'cooking_culinary',
        nodeLabel: 'Cooking & Culinary',
        kind: 'teach',
        usersLoader: users,
        randomLoader: random,
        sendRequest: sendRequest,
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
  testWidgets('category matches come first, then random Pals fill the deck', (
    tester,
  ) async {
    await _pump(
      tester,
      _app(
        users:
            (path, {required kind}) async => [
              _person('a', 'Alpha'),
              _person('b', 'Beta'),
            ],
        random: ({int limit = 20}) async => [_person('c', 'Gamma')],
      ),
    );

    expect(find.text('Cooking & Culinary'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);

    // The deck keeps going past the category with people from the wider pool.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Gamma'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('random fill never duplicates a category match', (tester) async {
    await _pump(
      tester,
      _app(
        users: (path, {required kind}) async => [_person('a', 'Alpha')],
        random:
            ({int limit = 20}) async => [
              _person('a', 'Alpha'),
              _person('b', 'Beta'),
            ],
      ),
    );

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('a full category skips the random pool', (tester) async {
    var randomCalls = 0;
    final people = [for (var i = 0; i < 12; i++) _person('p$i', 'Person $i')];

    await _pump(
      tester,
      _app(
        users: (path, {required kind}) async => people,
        random: ({int limit = 20}) async {
          randomCalls++;
          return const [];
        },
      ),
    );

    expect(find.text('Person 0'), findsOneWidget);
    expect(randomCalls, 0);
  });

  testWidgets('send request carries the card context and advances', (
    tester,
  ) async {
    String? sentId;
    String? sentSkill;
    String? sentPath;
    String? sentSource;

    await _pump(
      tester,
      _app(
        users:
            (path, {required kind}) async => [
              _person('a', 'Alpha'),
              _person('b', 'Beta'),
            ],
        random: ({int limit = 20}) async => const [],
        sendRequest: (id, {skillName, skillPath, source}) async {
          sentId = id;
          sentSkill = skillName;
          sentPath = skillPath;
          sentSource = source;
          return 'conn-1';
        },
      ),
    );

    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(sentId, 'a');
    expect(sentSkill, 'Filipino Cooking');
    expect(sentPath, 'cooking_culinary.filipino_cooking');
    expect(sentSource, 'browse');
    expect(find.text('Beta'), findsOneWidget);
    expect(
      find.textContaining('Connection request sent to Alpha'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed request keeps the same card', (tester) async {
    await _pump(
      tester,
      _app(
        users: (path, {required kind}) async => [_person('a', 'Alpha')],
        random: ({int limit = 20}) async => const [],
        sendRequest: (id, {skillName, skillPath, source}) async => null,
      ),
    );

    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.textContaining('Could not send this request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty category and pool show the empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        users: (path, {required kind}) async => const [],
        random: ({int limit = 20}) async => const [],
      ),
    );
    // The empty state hosts a looping Lottie, so settle would never finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('No people in this category yet.'), findsOneWidget);
    expect(find.text('Back to category'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that recovers', (tester) async {
    var attempts = 0;

    await _pump(
      tester,
      _app(
        users: (path, {required kind}) async {
          attempts++;
          if (attempts == 1) throw Exception('offline');
          return [_person('a', 'Alpha')];
        },
        random: ({int limit = 20}) async => const [],
      ),
    );

    expect(find.textContaining("Couldn't load users"), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deck fits 360 at 200% text', (tester) async {
    await _pump(
      tester,
      _app(
        users: (path, {required kind}) async => [_person('a', 'Alpha')],
        random: ({int limit = 20}) async => const [],
        surface: const Size(360, 640),
        textScale: 2,
      ),
      surface: const Size(360, 640),
    );

    expect(find.text('Cooking & Culinary'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deck renders in dark mode', (tester) async {
    await _pump(
      tester,
      _app(
        users: (path, {required kind}) async => [_person('a', 'Alpha')],
        random: ({int limit = 20}) async => const [],
        theme: darkMode,
      ),
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
