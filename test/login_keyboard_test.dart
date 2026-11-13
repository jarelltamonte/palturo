import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/authentication/login.dart';
import 'package:palturo/authentication/register.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PreferencesService.instance.init();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('login actions stay above a 300px keyboard', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const LoginPage()),
    );
    await tester.pumpAndSettle();

    const keyboardTop = 844.0 - 300.0;
    await tester.ensureVisible(find.text('Create new account'));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('Create new account')).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(
      tester.getRect(find.text('Log In')).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(
      tester.getRect(find.text('Forgot Password?')).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('register action stays above a 300px keyboard', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const RegisterPage()),
    );
    await tester.pumpAndSettle();

    const keyboardTop = 844.0 - 300.0;
    await tester.ensureVisible(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('Sign Up')).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(tester.takeException(), isNull);
  });
}
