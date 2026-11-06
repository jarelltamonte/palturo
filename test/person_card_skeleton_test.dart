import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/person_card_skeleton.dart';

void main() {
  testWidgets('skeleton fills short and reference phone decks', (tester) async {
    final semantics = tester.ensureSemantics();

    for (final size in [const Size(360, 640), const Size(390, 844)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: Scaffold(
            body: SizedBox(
              width: size.width - 32,
              height: size.height - 160,
              child: const PersonCardSkeleton(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.bySemanticsLabel('Loading recommendations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.binding.setSurfaceSize(null);
    semantics.dispose();
  });
}
