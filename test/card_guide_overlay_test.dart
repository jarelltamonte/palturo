import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/models/card_guide.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/card_guide_overlay.dart';

CardGuideKeys _keys({required bool optional}) => CardGuideKeys(
  card: GlobalKey(),
  skill: GlobalKey(),
  name: GlobalKey(),
  note: optional ? GlobalKey() : null,
  language: optional ? GlobalKey() : null,
  learningStyle: optional ? GlobalKey() : null,
  schedule: optional ? GlobalKey() : null,
  actions: GlobalKey(),
);

Widget _host(
  CardGuideKeys keys, {
  required Future<void> Function() onFinished,
  Size size = const Size(390, 844),
  double textScale = 1,
}) {
  return MaterialApp(
    theme: lightMode,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Builder(
          builder:
              (context) => Stack(
                children: [
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 40,
                    bottom: 40,
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.noScaling),
                      child: Container(
                        key: keys.card,
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Wants to teach Cooking', key: keys.skill),
                            Text('Grace Lim', key: keys.name),
                            if (keys.note != null)
                              Text('A note about the skill', key: keys.note),
                            if (keys.language != null)
                              Text('English, Filipino', key: keys.language),
                            if (keys.learningStyle != null)
                              Text(
                                'Hands-on Practice',
                                key: keys.learningStyle,
                              ),
                            if (keys.schedule != null)
                              Text('Mon, Wed, Fri', key: keys.schedule),
                            const Spacer(),
                            Row(
                              key: keys.actions,
                              children: const [
                                Flexible(child: Text('Skip')),
                                SizedBox(width: 8),
                                Flexible(child: Text('Send request')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CardGuideOverlay(keys: keys, onFinished: onFinished),
                  ),
                ],
              ),
        ),
      ),
    ),
  );
}

Future<void> _pumpGuide(
  WidgetTester tester,
  CardGuideKeys keys, {
  required Future<void> Function() onFinished,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _host(keys, onFinished: onFinished, size: size, textScale: textScale),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('walks every available card part with Next', (tester) async {
    final keys = _keys(optional: true);
    var finished = false;
    await _pumpGuide(tester, keys, onFinished: () async => finished = true);

    expect(find.text('Your first card'), findsOneWidget);
    expect(find.text('1 of 8'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('What they bring'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Who you are meeting'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('The note'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Learning style'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Your move'), findsOneWidget);
    expect(find.text('Start exploring'), findsOneWidget);

    await tester.tap(find.text('Start exploring'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('skips absent optional parts', (tester) async {
    final keys = _keys(optional: false);
    await _pumpGuide(tester, keys, onFinished: () async {});

    expect(find.text('1 of 4'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('What they bring'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Who you are meeting'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Your move'), findsOneWidget);
  });

  testWidgets('outside taps do not dismiss the guide', (tester) async {
    final keys = _keys(optional: true);
    await _pumpGuide(tester, keys, onFinished: () async {});

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Your first card'), findsOneWidget);
  });

  testWidgets('fits 360 at 200% text', (tester) async {
    final keys = _keys(optional: true);
    await _pumpGuide(
      tester,
      keys,
      onFinished: () async {},
      size: const Size(360, 640),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Your first card'), findsOneWidget);
  });
}
