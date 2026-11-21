import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/home_page.dart';
import 'package:palturo/services/app_shell_state.dart';
import 'package:palturo/services/card_guide_service.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/swipe_deck.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _person = Person(
  id: 'p1',
  name: 'Grace Lim',
  schedule: 'Weekends',
  language: 'English',
  learningStyle: 'Hands-on Practice',
  skillName: 'Cooking',
  role: PersonRole.mentor,
);

const _other = Person(
  id: 'p2',
  name: 'Rell Tamonte',
  schedule: 'Weekends',
  language: 'English',
  learningStyle: 'Discussion',
  skillName: 'Weaving',
  role: PersonRole.mentor,
);

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<Person> people,
  Set<String> seen = const {},
  bool Function()? isActive,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: lightMode,
      home: HomePage(
        key: UniqueKey(),
        deckLoader: ({bool force = false}) async => people,
        seenLoader: () async => seen,
        markSeen: (_) async {},
        unmarkSeen: (_) async {},
        onBrowse: () {},
        isActive: isActive,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    AppShellState.instance.reset();
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PreferencesService.instance.init();
    CardGuideService.instance.userIdOverride = 'guide-user';
  });

  tearDown(() {
    CardGuideService.instance.userIdOverride = null;
  });

  testWidgets('first real card opens the guide and locks deck actions', (
    tester,
  ) async {
    await _pumpHome(tester, people: const [_person]);

    expect(find.text('Your first card'), findsOneWidget);
    expect(find.text('1 of 7'), findsOneWidget);
    final deck = tester.widget<SwipeDeck>(find.byType(SwipeDeck));
    expect(deck.enabled, isFalse);
  });

  testWidgets('a seen deck suppresses the guide', (tester) async {
    await _pumpHome(
      tester,
      people: const [_person, _other],
      seen: const {'p1'},
    );

    expect(find.text('Your first card'), findsNothing);
  });

  testWidgets('the guide flag suppresses the guide', (tester) async {
    await PreferencesService.instance.setBool(
      'card_guide_seen_v1_guide-user',
      true,
    );
    await _pumpHome(tester, people: const [_person]);

    expect(find.text('Your first card'), findsNothing);
  });

  testWidgets('no card means no guide', (tester) async {
    await _pumpHome(tester, people: const []);

    expect(find.text('Your first card'), findsNothing);
  });

  testWidgets('the guide waits until For You is the active tab', (
    tester,
  ) async {
    var active = false;
    await _pumpHome(tester, people: const [_person], isActive: () => active);

    expect(find.text('Your first card'), findsNothing);
    // Deferred, not consumed: the next visit to For You must still show it.
    expect(await CardGuideService.instance.shouldShow(const {}), isTrue);

    active = true;
    AppShellState.instance.setSelectedTab(1);
    await tester.pumpAndSettle();

    expect(find.text('Your first card'), findsOneWidget);
  });

  testWidgets('leaving the tab closes the guide and it never returns', (
    tester,
  ) async {
    var active = true;
    await _pumpHome(tester, people: const [_person], isActive: () => active);
    expect(find.text('Your first card'), findsOneWidget);

    active = false;
    AppShellState.instance.setSelectedTab(1);
    await tester.pumpAndSettle();
    expect(find.text('Your first card'), findsNothing);

    // Returning to For You must not replay a guide the account already saw.
    active = true;
    AppShellState.instance.setSelectedTab(0);
    await tester.pumpAndSettle();
    expect(find.text('Your first card'), findsNothing);
  });

  testWidgets('the one-time flag is written as soon as the guide opens', (
    tester,
  ) async {
    await _pumpHome(tester, people: const [_person]);
    expect(find.text('Your first card'), findsOneWidget);

    expect(await CardGuideService.instance.shouldShow(const {}), isFalse);
  });

  testWidgets('completing the guide persists and does not repeat', (
    tester,
  ) async {
    await _pumpHome(tester, people: const [_person]);
    expect(find.text('Your first card'), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Start exploring'), findsOneWidget);
    await tester.tap(find.text('Start exploring'));
    await tester.pumpAndSettle();

    expect(find.text('Your first card'), findsNothing);

    await _pumpHome(tester, people: const [_person]);
    expect(find.text('Your first card'), findsNothing);
  });
}
