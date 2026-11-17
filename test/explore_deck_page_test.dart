import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/explore_deck_page.dart';
import 'package:palturo/theme/theme.dart';

Person person(String id, String name) => Person(
  id: id,
  name: name,
  schedule: 'Weekends',
  language: 'English',
  learningStyle: 'Hands-on Practice',
  skillName: 'Cooking',
  role: PersonRole.mentor,
);

void main() {
  testWidgets('opens on a random card and never repeats one', (tester) async {
    final key = GlobalKey<ExploreDeckPageState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ExploreDeckPage(
          key: key,
          batchSize: 2,
          loader:
              ({int limit = 20}) async => [
                person('a', 'Alpha'),
                person('b', 'Beta'),
              ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(key.currentState!.loadedCount, 2);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsOneWidget);
    expect(key.currentState!.loadedCount, 2);

    // The pool is exhausted, so the deck ends instead of showing Alpha again.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
    expect(
      find.textContaining('No more random Pals are available'),
      findsOneWidget,
    );
  });

  testWidgets('a one-person pool stops instead of looping the same card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ExploreDeckPage(
          batchSize: 1,
          loader: ({int limit = 20}) async => [person('p', 'Para Cetamol')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Para Cetamol'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Para Cetamol'), findsNothing);
    expect(
      find.textContaining('No more random Pals are available'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sending a request carries the random card skill context', (
    tester,
  ) async {
    String? sentId;
    String? sentSkill;
    String? sentPath;
    String? sentSource;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ExploreDeckPage(
          batchSize: 1,
          loader:
              ({int limit = 20}) async => [
                Person(
                  id: 'b',
                  name: 'Beta',
                  schedule: 'Weekends',
                  language: 'English',
                  learningStyle: 'Hands-on Practice',
                  skillName: 'Filipino Cooking',
                  skillPath: 'cooking_culinary.filipino_cooking',
                  role: PersonRole.mentor,
                ),
              ],
          sendRequest: (id, {skillName, skillPath, source}) async {
            sentId = id;
            sentSkill = skillName;
            sentPath = skillPath;
            sentSource = source;
            return 'conn-1';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(sentId, 'b');
    expect(sentSkill, 'Filipino Cooking');
    expect(sentPath, 'cooking_culinary.filipino_cooking');
    expect(sentSource, 'explore');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ExploreDeckPage(
          loader: ({int limit = 20}) async {
            attempts++;
            if (attempts == 1) throw Exception('offline');
            return [person('a', 'Alpha')];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't load random Pals"), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('an empty pool shows the empty state with a retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ExploreDeckPage(loader: ({int limit = 20}) async => const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No random Pals are available right now.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('duplicate people are only dealt once', (tester) async {
    final key = GlobalKey<ExploreDeckPageState>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ExploreDeckPage(
          key: key,
          batchSize: 3,
          loader: ({int limit = 20}) async {
            calls++;
            if (calls > 1) return const [];
            return [
              person('a', 'Alpha'),
              person('a', 'Alpha again'),
              person('b', 'Beta'),
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(key.currentState!.loadedCount, 2);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('an exhausted pool reports that nothing is left', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ExploreDeckPage(
          batchSize: 1,
          loader: ({int limit = 20}) async {
            calls++;
            return calls == 1 ? [person('a', 'Alpha')] : const [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No more random Pals are available'),
      findsOneWidget,
    );
  });

  testWidgets('explore deck fits 360 at 200% text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: ExploreDeckPage(
            loader: ({int limit = 20}) async => [person('a', 'Alpha')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explore deck renders in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: darkMode,
        home: ExploreDeckPage(
          loader: ({int limit = 20}) async => [person('a', 'Alpha')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Send request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
