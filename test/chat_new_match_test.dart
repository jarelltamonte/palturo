import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Person _person() => Person(
  id: 'p1',
  name: 'Lolo Ben Cruz',
  schedule: 'Weekends',
  language: 'Filipino, English',
  learningStyle: 'Hands-on Practice',
  skillName: 'Kitchen Basics',
  role: PersonRole.learner,
  bio: 'Retired cook from Batangas.',
);

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
  testWidgets('a starter fills the composer and hides the sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: ChatRoom(
          name: 'Lolo Ben Cruz',
          skillName: 'Kitchen Basics',
          role: PersonRole.learner,
          person: _person(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start the conversation'), findsOneWidget);
    expect(find.text('Weekends'), findsOneWidget);

    await tester.tap(find.byTooltip('Use this starter').first);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, contains('Kitchen Basics'));
    expect(field.focusNode!.hasFocus, isTrue);
    // The empty state steps aside once the composer has content.
    expect(find.text('Start the conversation'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
