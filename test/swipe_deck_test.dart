import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/widgets/swipe_deck.dart';

void main() {
  testWidgets('SwipeDeck commits and pops in the next card', (tester) async {
    var card = 'a';
    var swipes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SwipeDeck(
                cardKey: card,
                hintEnabled: false,
                onSwiped: (right) {
                  setState(() {
                    swipes++;
                    card = 'b';
                  });
                },
                child: Container(
                  key: ValueKey(card),
                  color: Colors.teal,
                  alignment: Alignment.center,
                  child: Text(card),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('a')), findsOneWidget);
    expect(find.byKey(const ValueKey('b')), findsNothing);

    await tester.drag(find.byType(SwipeDeck), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(swipes, 1);
    expect(find.byKey(const ValueKey('a')), findsNothing);
    expect(find.byKey(const ValueKey('b')), findsOneWidget);
  });

  testWidgets('SwipeDeck restores a card below threshold', (tester) async {
    var swipes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeDeck(
            cardKey: 'a',
            hintEnabled: false,
            onSwiped: (_) => swipes++,
            child: Container(
              key: const ValueKey('a'),
              color: Colors.teal,
              alignment: Alignment.center,
              child: const Text('a'),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(SwipeDeck), const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(swipes, 0);
    expect(find.byKey(const ValueKey('a')), findsOneWidget);
  });

  testWidgets('SwipeDeck hint does not throw or block input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeDeck(
            cardKey: 'a',
            onSwiped: (_) {},
            child: Container(
              key: const ValueKey('a'),
              color: Colors.teal,
              alignment: Alignment.center,
              child: const Text('a'),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('a')), findsOneWidget);
  });

  testWidgets('SwipeDeck reset restores the same card', (tester) async {
    final key = GlobalKey<SwipeDeckState>();
    var swipes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeDeck(
            key: key,
            cardKey: 'a',
            hintEnabled: false,
            onSwiped: (_) => swipes++,
            child: Container(
              key: const ValueKey('a'),
              color: Colors.teal,
              alignment: Alignment.center,
              child: const Text('a'),
            ),
          ),
        ),
      ),
    );

    key.currentState!.dismiss(right: true);
    await tester.pumpAndSettle();
    expect(swipes, 1);

    key.currentState!.reset();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('a')), findsOneWidget);
  });

  testWidgets('SwipeDeck ignores a second dismiss while exiting', (
    tester,
  ) async {
    final key = GlobalKey<SwipeDeckState>();
    var swipes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeDeck(
            key: key,
            cardKey: 'a',
            hintEnabled: false,
            onSwiped: (_) => swipes++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    key.currentState!.dismiss(right: true);
    key.currentState!.dismiss(right: true);
    await tester.pumpAndSettle();

    expect(swipes, 1);
  });

  testWidgets('SwipeDeck busy state replaces the decision surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeDeck(
            cardKey: 'a',
            hintEnabled: false,
            busy: true,
            onSwiped: (_) {},
            child: Container(color: Colors.teal),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(SwipeDeck), const Offset(400, 0));
    await tester.pump();

    expect(find.textContaining('Sending request'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
