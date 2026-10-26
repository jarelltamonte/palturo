import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/authentication/login.dart';
import 'package:palturo/authentication/register.dart';
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_edit.dart';
import 'package:palturo/screen/navigation_bar.dart';
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

  testWidgets('empty login shows inline errors and 44px forgot target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const LoginPage()),
    );
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    final forgot = tester.getSize(find.text('Forgot Password?'));
    expect(forgot.height, greaterThanOrEqualTo(0));
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.text('Forgot Password?'),
              matching: find.byType(TextButton),
            ),
          )
          .height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('register legal links are 44px buttons', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const RegisterPage()),
    );
    await tester.pumpAndSettle();
    final back = tester.getSize(
      find.ancestor(
        of: find.text('Back to Log In'),
        matching: find.byType(TextButton),
      ),
    );
    expect(back.height, greaterThanOrEqualTo(44));
    for (final label in ['Terms of Service', 'Data Policy', 'Cookies Policy']) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('core routes survive 200% text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const Settings()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ChatRoom(connectionId: null, name: 'Alexandra Very Long Name'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: PersonCardOverlay(
            person: Person(
              id: 'p1',
              name: 'Alexandra Very Long Name',
              schedule: 'Fri/Weekends',
              language: 'English, Filipino',
              learningStyle: 'Hands-on Practice',
              skillName: 'Barong Embroidery',
              role: PersonRole.mentor,
              bio: 'A long bio that should wrap instead of overflowing.',
            ),
            onAdd: () {},
            onSkip: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('360x640 at 200% keeps edit and chat reachable', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ProfileEditPage(
          profile: ProfileData(
            id: 'p1',
            name: 'Alexandra Very Long Name',
            schedule: 'Fri/Weekends',
            availableDays: const ['Friday', 'Saturday'],
            bio: 'A long bio that should wrap.',
            languages: const ['English', 'Filipino'],
            interests: const ['Hands-on Practice'],
            role: OnboardingRole.both,
            learningSkillIds: const ['cooking_pinakbet'],
            teachingSkillIds: const ['barong_embroidery'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ChatRoom(
          connectionId: null,
          name: 'Alexandra Very Long Name',
          skillName: 'Barong Embroidery',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('person card keeps name single-line at 100%', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: PersonCardOverlay(
            person: Person(
              id: 'p1',
              name: 'Aling Rosa Reyes',
              schedule: 'Fri/Weekends',
              language: 'English, Filipino',
              learningStyle: 'Hands-on Practice',
              skillName: 'Barong Embroidery',
              role: PersonRole.mentor,
              bio: 'A long bio that should wrap instead of overflowing.',
            ),
            onAdd: () {},
            onSkip: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final name = tester.getRect(find.text('Aling Rosa Reyes'));
    expect(name.height, lessThan(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating nav survives 200% text without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const NavigationBarWidget()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
