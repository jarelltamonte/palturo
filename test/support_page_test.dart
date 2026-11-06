import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/account/support_page.dart';
import 'package:palturo/theme/theme.dart';

void main() {
  testWidgets('delete-support copy has a real support route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const SupportPage()),
    );
    expect(find.text('Support'), findsOneWidget);
    expect(find.text(SupportPage.supportEmail), findsOneWidget);
    expect(find.text('Copy support email'), findsOneWidget);
  });
}
