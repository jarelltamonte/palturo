import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/request_card.dart';
import 'package:palturo/theme/theme.dart';

Widget host(Widget child) => MaterialApp(
  theme: lightMode,
  home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
);

RequestCard card({required Future<bool> Function() onAccept}) => RequestCard(
  skillName: 'Cooking',
  requesterName: 'Test Pal',
  schedule: 'Weekends',
  language: 'English',
  learningStyle: 'Hands-on Practice',
  timeAgo: 'now',
  onAccept: onAccept,
  onDecline: () {},
);

void main() {
  testWidgets('accept failure flips the card back to pending', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      host(
        card(
          onAccept: () async {
            calls++;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accept'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Start chatting'), findsNothing);
  });

  testWidgets('accept success shows the accepted back', (tester) async {
    await tester.pumpWidget(host(card(onAccept: () async => true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Start chatting'), findsOneWidget);
  });
}
