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
  testWidgets('opens directly on a random card and keeps the deck fed', (
    tester,
  ) async {
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
    expect(key.currentState!.loadedCount, greaterThanOrEqualTo(2));

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsOneWidget);
    expect(key.currentState!.loadedCount, greaterThanOrEqualTo(4));
  });

  testWidgets('sending a request carries the random card skill context', (
    tester,
  ) async {
    String? sentId;
    String? sentSkill;
    String? sentPath;

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
          sendRequest: (id, {skillName, skillPath}) async {
            sentId = id;
            sentSkill = skillName;
            sentPath = skillPath;
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
}
