import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/profile_update_link.dart';

void main() {
  testWidgets('empty-state profile link has a working target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(body: ProfileUpdateLink(onTap: () => taps++)),
      ),
    );
    expect(find.text('Update your profile'), findsOneWidget);
    await tester.tap(find.text('Update your profile'));
    expect(taps, 1);
  });
}
