import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/settings.dart';
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

  testWidgets('survey back preserves the previous rating', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const Settings()),
    );
    await tester.pumpAndSettle();

    final feedback = find.text('Send feedback');
    await tester.ensureVisible(feedback);
    await tester.tap(feedback);
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 12'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strongly agree'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 12'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 12'), findsOneWidget);

    final optOut = find.text('Prefer not to answer');
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(optOut);
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 12'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 12'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard feedback?'), findsOneWidget);
    await tester.tap(find.text('Keep writing'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 12'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard feedback?'), findsOneWidget);
    await tester.tap(find.text('Keep writing'));
    await tester.pumpAndSettle();
  });

  testWidgets('iOS survey actions fit a 360x640 viewport', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const Settings()),
    );
    await tester.pumpAndSettle();
    final feedback = find.text('Send feedback');
    await tester.scrollUntilVisible(
      find.text('Send feedback'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(feedback);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prefer not to answer'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 12'), findsOneWidget);

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.text('Prefer not to answer'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Step 12 of 12'), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(const Duration(milliseconds: 600));
    final submit = tester.getRect(find.text('Submit'));
    expect(submit.bottom, lessThanOrEqualTo(640 - 300 + 1));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS tall dialog reaches the comment step without errors', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const Settings()),
    );
    await tester.pumpAndSettle();
    final feedback = find.text('Send feedback');
    await tester.ensureVisible(feedback);
    await tester.tap(feedback);
    await tester.pumpAndSettle();

    for (var i = 0; i < 11; i++) {
      await tester.tap(find.text('Prefer not to answer'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Step 12 of 12'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(const Duration(milliseconds: 600));
    final field = tester.getRect(find.byType(TextField));
    final submit = tester.getRect(find.text('Submit'));
    expect(field.bottom, lessThanOrEqualTo(submit.top + 1));
    expect(submit.bottom, lessThanOrEqualTo(844 - 300 + 1));
    debugDefaultTargetPlatformOverride = null;
  });
}
