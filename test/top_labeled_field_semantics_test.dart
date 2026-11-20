import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/authentication/login.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/top_labeled_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('unfocused fields are labelled, enterable text boxes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const LoginPage()),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Email'), findsOneWidget);
    expect(find.bySemanticsLabel('Password'), findsOneWidget);

    final email =
        tester.getSemantics(find.bySemanticsLabel('Email')).getSemanticsData();
    expect(email.label, 'Email');
    expect(email.flagsCollection.isTextField, isTrue);
    expect(email.hasAction(SemanticsAction.tap), isTrue);
    expect(email.hasAction(SemanticsAction.focus), isTrue);

    final password =
        tester
            .getSemantics(find.bySemanticsLabel('Password'))
            .getSemanticsData();
    expect(password.label, 'Password');
    expect(password.flagsCollection.isTextField, isTrue);
    expect(password.flagsCollection.isObscured, isTrue);
    expect(password.hasAction(SemanticsAction.tap), isTrue);
    expect(password.hasAction(SemanticsAction.focus), isTrue);
    handle.dispose();
  });

  testWidgets('semantics tap opens the field and typing stays obscured', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const LoginPage()),
    );
    await tester.pumpAndSettle();

    tester.semantics.tap(find.semantics.byLabel('Email'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(find.byType(EditableText).at(1), 'secret123');
    await tester.pumpAndSettle();
    final password =
        tester
            .getSemantics(find.bySemanticsLabel('Password'))
            .getSemanticsData();
    expect(password.flagsCollection.isObscured, isTrue);
    expect(password.value, isNot(contains('secret123')));
    handle.dispose();
  });

  testWidgets('tapping the field surface still focuses it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const LoginPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TopLabeledField).first);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
