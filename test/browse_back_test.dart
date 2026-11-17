import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/explore_page.dart';
import 'package:palturo/screen/navigation_bar.dart';
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

  testWidgets('one back press keeps the Browse root page alive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const NavigationBarWidget()),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Browse').last);
    await tester.pumpAndSettle();

    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    nav.push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('domain-page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExplorePage, skipOffstage: false), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // The domain route pops, the Browse root must stay mounted. A second pop
    // (shell + nested handler) would leave the tab blank.
    expect(find.byType(ExplorePage, skipOffstage: false), findsOneWidget);
    expect(nav.canPop(), isFalse);
  });
}
