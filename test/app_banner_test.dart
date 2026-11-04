import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/app_banner.dart';
import 'package:palturo/widgets/match_banner.dart';

void main() {
  setUp(() {
    AppBannerController.instance.clear();
  });

  tearDown(() {
    AppBannerController.instance.clear();
  });

  testWidgets('standard banner renders, routes, and dismisses', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: AppBannerHost(child: const Scaffold(body: Text('content'))),
      ),
    );

    AppBannerController.instance.show(
      AppBannerData(
        id: 'n1',
        title: 'New request',
        body: 'RJ wants to exchange Barong with you.',
        icon: Icons.person_add_alt_1,
        onTap: () => tapped = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New request'), findsOneWidget);
    expect(find.text('RJ wants to exchange Barong with you.'), findsOneWidget);

    await tester.tap(find.text('New request'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(AppBannerController.instance.current.value, isNull);
  });

  testWidgets('banner uses the dark surface in dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: darkMode,
        home: AppBannerHost(
          isDark: true,
          child: const Scaffold(body: Text('content')),
        ),
      ),
    );

    AppBannerController.instance.show(
      const AppBannerData(
        id: 'dark1',
        title: 'Dark banner',
        body: 'Surface check',
        icon: Icons.notifications_none,
      ),
    );
    await tester.pumpAndSettle();

    final colors =
        tester
            .widgetList<Container>(find.byType(Container))
            .map((container) => container.decoration)
            .whereType<BoxDecoration>()
            .map((decoration) => decoration.color)
            .toList();
    expect(colors, contains(AppColors.elevatedDark));
    AppBannerController.instance.clear();
  });

  testWidgets('match banner exposes the say-hello action', (tester) async {
    var saidHello = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: AppBannerHost(child: const Scaffold(body: Text('content'))),
      ),
    );

    AppBannerController.instance.show(
      buildMatchBanner(
        id: 'c1',
        name: 'RJ Castillano',
        skillName: 'Barong Embroidery',
        onSayHello: () => saidHello = true,
      ),
      preempt: true,
    );
    await tester.pumpAndSettle();

    expect(find.text("You're now Pals with RJ Castillano"), findsOneWidget);
    expect(find.text('Matched on Barong Embroidery'), findsOneWidget);
    expect(find.text('Say hello'), findsOneWidget);

    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();

    expect(saidHello, isTrue);
    expect(AppBannerController.instance.current.value, isNull);
  });

  testWidgets('message updates coalesce for the same conversation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: AppBannerHost(child: const Scaffold(body: Text('content'))),
      ),
    );

    AppBannerController.instance.show(
      const AppBannerData(
        id: 'm1',
        groupKey: 'chat:c1',
        title: 'Grace',
        body: 'First message',
        icon: Icons.chat_bubble_outline,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First message'), findsOneWidget);

    AppBannerController.instance.showOrUpdate(
      const AppBannerData(
        id: 'm2',
        groupKey: 'chat:c1',
        title: 'Grace',
        body: 'Second message',
        icon: Icons.chat_bubble_outline,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second message'), findsOneWidget);
    expect(find.text('First message'), findsNothing);
    AppBannerController.instance.clear();
  });

  testWidgets('match banner preempts and restores the queued banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: AppBannerHost(child: const Scaffold(body: Text('content'))),
      ),
    );

    AppBannerController.instance.show(
      const AppBannerData(
        id: 'n1',
        title: 'New request',
        body: 'Queued behind the match',
        icon: Icons.person_add_alt_1,
      ),
    );
    await tester.pumpAndSettle();

    AppBannerController.instance.show(
      buildMatchBanner(id: 'c1', name: 'RJ', onSayHello: () {}),
      preempt: true,
    );
    await tester.pumpAndSettle();
    expect(find.text("You're now Pals with RJ"), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss notification'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('New request'), findsOneWidget);
    AppBannerController.instance.clear();
  });
}
