import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/widgets/showcase_media.dart';

void main() {
  test('video showcase URLs are detected without treating photos as video', () {
    expect(isVideoUrl('https://example.test/clip.mp4'), isTrue);
    expect(isVideoUrl('https://example.test/clip.webm?token=1'), isTrue);
    expect(isVideoUrl('https://example.test/clip.mov'), isTrue);
    expect(isVideoUrl('https://example.test/photo.jpg'), isFalse);
    expect(isVideoUrl(null), isFalse);
  });

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

  Widget harness({
    double textScale = 1.0,
    Person? personOverride,
    VoidCallback? onOpenProfile,
    VoidCallback? onWhyMatch,
  }) => MaterialApp(
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
            child: PersonCardOverlay(
              person: personOverride ?? person(),
              onOpenProfile: onOpenProfile,
              onWhyMatch: onWhyMatch,
            ),
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

    final dot0 = find.descendant(
      of: find.byKey(const ValueKey('card-dot-0')),
      matching: find.byType(AnimatedContainer),
    );
    final dot1 = find.descendant(
      of: find.byKey(const ValueKey('card-dot-1')),
      matching: find.byType(AnimatedContainer),
    );
    expect(dot0, findsOneWidget);
    expect(dot1, findsOneWidget);
    expect(tester.getSize(dot0).width, 20);
    expect(tester.getSize(dot1).width, 8);

    // Right half advances through the combined showcase + photo list.
    await tester.tapAt(const Offset(550, 150));
    await tester.pumpAndSettle();
    expect(tester.getSize(dot0).width, 8);
    expect(tester.getSize(dot1).width, 20);

    await tester.tapAt(const Offset(250, 150));
    await tester.pumpAndSettle();
    expect(tester.getSize(dot0).width, 20);
    expect(tester.getSize(dot1).width, 8);

    // Dots jump directly to a page and remain bounded.
    await tester.tap(find.byKey(const ValueKey('card-dot-1')));
    await tester.pumpAndSettle();
    expect(tester.getSize(dot1).width, 20);
  });

  testWidgets('many media pages use a counter instead of overflowing', (
    tester,
  ) async {
    final manyMedia = Person(
      id: 'p2',
      name: 'Alex Example',
      schedule: 'Weekends',
      language: 'English',
      learningStyle: 'Visual',
      skillName: 'Spanish',
      role: PersonRole.learner,
      bio: bio,
      showcaseUrls: const [],
      photoUrls: List<String?>.filled(12, null),
    );

    await tester.pumpWidget(harness(personOverride: manyMedia));
    await tester.pumpAndSettle();

    expect(find.text('1 / 12'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-dot-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing media uses the neutral initials fallback', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('AE'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compatibility chip explains the reciprocal match', (
    tester,
  ) async {
    var whyOpened = false;
    var profileOpened = false;
    final matched = Person(
      id: 'p3',
      name: 'Alex Example',
      schedule: 'Weekends',
      language: 'English',
      learningStyle: 'Visual',
      skillName: 'Spanish',
      role: PersonRole.mentor,
      bio: bio,
      compatibility: 0.86,
      showcaseUrls: const [null],
      photoUrls: const [null],
    );

    await tester.pumpWidget(
      harness(
        personOverride: matched,
        onWhyMatch: () => whyOpened = true,
        onOpenProfile: () => profileOpened = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('86% match'), findsOneWidget);
    expect(find.text('View profile'), findsOneWidget);

    await tester.tap(find.text('86% match'));
    await tester.pumpAndSettle();
    expect(whyOpened, isTrue);

    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(profileOpened, isTrue);

    profileOpened = false;
    await tester.tapAt(const Offset(400, 160));
    await tester.pumpAndSettle();
    expect(profileOpened, isTrue);
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
