import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/discoverability_status.dart';

Widget _host(
  Widget child, {
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
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('hidden state explains visibility and offers the showcase CTA', (
    tester,
  ) async {
    var action = 0;
    await tester.pumpWidget(
      _host(
        DiscoverabilityStatusCard(
          wantsTeaching: true,
          hasAnyShowcase: false,
          missingSkillLabels: const ['Vocal Music', 'Sewing'],
          onAction: () => action++,
        ),
      ),
    );

    expect(find.text('You are hidden from discovery'), findsOneWidget);
    expect(
      find.textContaining('at least one photo or short video'),
      findsOneWidget,
    );
    expect(find.text('Vocal Music'), findsOneWidget);
    expect(find.text('Sewing'), findsOneWidget);
    await tester.tap(find.text('Add a showcase'));
    expect(action, 1);
  });

  testWidgets('partial state nudges the remaining skills', (tester) async {
    await tester.pumpWidget(
      _host(
        DiscoverabilityStatusCard(
          wantsTeaching: true,
          hasAnyShowcase: true,
          missingSkillLabels: const ['Sewing'],
          onAction: () {},
        ),
      ),
    );

    expect(find.text('1 teaching skill needs a showcase'), findsOneWidget);
    expect(find.text('Review teaching skills'), findsOneWidget);
    expect(find.textContaining('You are visible'), findsOneWidget);
  });

  testWidgets('complete state is compact and learner-only is hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DiscoverabilityStatusCard(
          wantsTeaching: true,
          hasAnyShowcase: true,
          missingSkillLabels: [],
        ),
      ),
    );
    expect(find.text('You are visible in discovery'), findsOneWidget);
    expect(find.text('Add a showcase'), findsNothing);

    await tester.pumpWidget(
      _host(
        const DiscoverabilityStatusCard(
          wantsTeaching: false,
          hasAnyShowcase: false,
          missingSkillLabels: ['Sewing'],
        ),
      ),
    );
    expect(find.text('You are hidden from discovery'), findsNothing);
  });

  testWidgets('fits 360 at 200% text', (tester) async {
    await tester.pumpWidget(
      _host(
        DiscoverabilityStatusCard(
          wantsTeaching: true,
          hasAnyShowcase: false,
          missingSkillLabels: const [
            'Vocal Music',
            'Sewing',
            'Filipino Cooking',
          ],
          onAction: () {},
        ),
        size: const Size(360, 640),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('You are hidden from discovery'), findsOneWidget);
  });
}
