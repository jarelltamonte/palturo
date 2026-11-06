import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/home_page.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/theme.dart';

void main() {
  test('the iOS top bar still fits a 48px target', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(AppSpacing.topBarHeight(), greaterThanOrEqualTo(48));
  });

  testWidgets('home trailing actions are 48px and end at x=350', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final never = Completer<List<Person>>();
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: HomePage(deckLoader: ({bool force = false}) => never.future),
      ),
    );
    await tester.pump();

    for (final label in [
      'Activity',
      'Undo last person',
      'Filter recommendations',
    ]) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, 48, reason: '$label width');
      expect(size.height, 48, reason: '$label height');
    }

    final filter = tester.getRect(
      find.bySemanticsLabel('Filter recommendations'),
    );
    expect(filter.center.dx, closeTo(350, 0.5));
  });
}
