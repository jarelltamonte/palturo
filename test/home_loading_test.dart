import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/home_page.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/person_card_skeleton.dart';

void main() {
  testWidgets('cold deck shows slow copy at 4s and timeout retry at 12s', (
    tester,
  ) async {
    final never = Completer<List<Person>>();

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: HomePage(deckLoader: ({bool force = false}) => never.future),
      ),
    );
    await tester.pump();

    expect(find.text('Still looking for matches…'), findsNothing);
    expect(find.text('Retry'), findsNothing);

    await tester.pump(kDeckSlowThreshold);
    expect(find.text('Still looking for matches…'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.pump(kDeckTimeout);
    await tester.pump();

    expect(find.textContaining('taking longer'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a completed cold deck replaces the skeleton', (tester) async {
    final done = Completer<List<Person>>();

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: HomePage(deckLoader: ({bool force = false}) => done.future),
      ),
    );
    await tester.pump();
    expect(find.text('Still looking for matches…'), findsNothing);

    done.complete(const []);
    await tester.pump();
    await tester.pump();

    expect(find.byType(PersonCardSkeleton), findsNothing);
    expect(find.text('You have seen all the top results'), findsOneWidget);
    expect(find.text('Still looking for matches…'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('retry re-arms the slow state and ignores the stale load', (
    tester,
  ) async {
    final calls = <Completer<List<Person>>>[];
    Future<List<Person>> load({bool force = false}) {
      final call = Completer<List<Person>>();
      calls.add(call);
      return call.future;
    }

    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: HomePage(deckLoader: load)),
    );
    await tester.pump();
    await tester.pump(kDeckSlowThreshold);
    expect(find.text('Still looking for matches…'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(calls, hasLength(2));
    expect(find.text('Still looking for matches…'), findsNothing);

    await tester.pump(kDeckSlowThreshold);
    expect(find.text('Still looking for matches…'), findsOneWidget);

    // The superseded first load must not cancel the retry's timers.
    calls.first.complete(const []);
    await tester.pump();
    await tester.pump();
    expect(find.text('Still looking for matches…'), findsOneWidget);

    await tester.pump(kDeckTimeout);
    await tester.pump();
    expect(find.textContaining('taking longer'), findsOneWidget);
  });
}
