import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';

void main() {
  const bio =
      'I love learning languages and teaching others every single day. '
      'Ask me about music, travel, and cooking.';

  Person person() => const Person(
    id: 'p1',
    name: 'Alex Example',
    schedule: 'Weekends',
    language: 'English',
    learningStyle: 'Visual',
    skillName: 'Spanish',
    role: PersonRole.learner,
    bio: bio,
    showcaseUrls: [null],
    photoUrls: [null],
  );

  Widget harness({double textScale = 1.0}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 500),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 500,
            child: PersonCardOverlay(person: person()),
          ),
        ),
      ),
    ),
  );

  testWidgets('card media pages include showcase pages and stay bounded', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final dots = find.byType(AnimatedContainer);
    expect(dots, findsNWidgets(2));
    expect(tester.getSize(dots.at(0)).width, 24);
    expect(tester.getSize(dots.at(1)).width, 8);

    // Right half advances through the combined showcase + photo list.
    await tester.tapAt(const Offset(490, 150));
    await tester.pumpAndSettle();
    expect(tester.getSize(dots.at(0)).width, 8);
    expect(tester.getSize(dots.at(1)).width, 24);

    await tester.tapAt(const Offset(310, 150));
    await tester.pumpAndSettle();
    expect(tester.getSize(dots.at(0)).width, 24);
    expect(tester.getSize(dots.at(1)).width, 8);

    // Dots jump directly to a page and remain bounded.
    await tester.tap(find.byKey(const ValueKey('card-dot-1')));
    await tester.pumpAndSettle();
    expect(tester.getSize(dots.at(1)).width, 24);
  });

  testWidgets('expanded bio scrolls instead of overflowing', (tester) async {
    await tester.pumpWidget(harness(textScale: 2.5));
    await tester.pumpAndSettle();

    await tester.tap(find.text(bio));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
