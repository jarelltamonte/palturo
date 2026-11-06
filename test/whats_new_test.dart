import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/whats_new_sheet.dart';

void main() {
  testWidgets("what's new sheet renders bullets at 360/200%", (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(body: WhatsNewSheet()),
        ),
      ),
    );

    expect(find.text("What's new"), findsOneWidget);
    for (final bullet in whatsNewBullets) {
      expect(find.text(bullet), findsOneWidget);
    }
    expect(find.text('Got it'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
