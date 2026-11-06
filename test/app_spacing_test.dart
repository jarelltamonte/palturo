import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/app_spacing.dart';

void main() {
  testWidgets('tab-bar clearance adds 16px to the shell bottom padding', (
    tester,
  ) async {
    Future<double> read(double bottom) async {
      late double value;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              padding: EdgeInsets.only(bottom: bottom),
            ),
            child: Builder(
              builder: (context) {
                value = AppSpacing.bottomNavClearanceFor(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return value;
    }

    // The shell injects the nav height (60/74 + safe area) as padding.bottom.
    expect(await read(80), 96);
    expect(await read(94), 110);
    expect(await read(108), 124);
  });
}
