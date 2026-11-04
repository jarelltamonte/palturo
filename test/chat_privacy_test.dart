import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/settings/chat_privacy_page.dart';
import 'package:palturo/services/chat_privacy_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/utils/presence_label.dart';

void main() {
  setUp(() => ChatPrivacyService.instance.reset());

  test('presence labels respect privacy and age', () {
    final now = DateTime(2026, 11, 5, 12);
    final enabled = true;

    expect(presenceLabel(null, enabled: enabled, now: now), isNull);
    expect(
      presenceLabel(
        now.subtract(const Duration(minutes: 1)),
        enabled: false,
        now: now,
      ),
      isNull,
    );
    expect(
      presenceLabel(
        now.subtract(const Duration(minutes: 1)),
        enabled: enabled,
        now: now,
      ),
      'Online',
    );
    expect(
      presenceLabel(
        now.subtract(const Duration(minutes: 20)),
        enabled: enabled,
        now: now,
      ),
      'Active 20m ago',
    );
    expect(
      presenceLabel(
        now.subtract(const Duration(hours: 3)),
        enabled: enabled,
        now: now,
      ),
      'Active 3h ago',
    );
    expect(
      presenceLabel(
        now.subtract(const Duration(days: 2)),
        enabled: enabled,
        now: now,
      ),
      'Active 2d ago',
    );
    expect(
      presenceLabel(
        now.subtract(const Duration(days: 30)),
        enabled: enabled,
        now: now,
      ),
      isNull,
    );
  });

  test('online window is two minutes', () {
    final now = DateTime(2026, 11, 5, 12);
    expect(
      presenceIsOnline(
        now.subtract(const Duration(seconds: 90)),
        enabled: true,
        now: now,
      ),
      isTrue,
    );
    expect(
      presenceIsOnline(
        now.subtract(const Duration(minutes: 3)),
        enabled: true,
        now: now,
      ),
      isFalse,
    );
    expect(
      presenceIsOnline(
        now.subtract(const Duration(seconds: 10)),
        enabled: false,
        now: now,
      ),
      isFalse,
    );
  });

  testWidgets('chat privacy page renders all controls at 200%', (tester) async {
    ChatPrivacyService.instance.debugSetLoaded();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: const ChatPrivacyPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Chat privacy'), findsOneWidget);
    expect(find.text('Show when I am online'), findsOneWidget);
    expect(find.text('Typing indicators'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Show read receipts'), 200);
    expect(find.text('Show read receipts'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Who can see my status: Pals only'),
      200,
    );
    expect(find.text('Who can see my status: Pals only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page blocks editing until privacy state loads', (tester) async {
    ChatPrivacyService.instance.reset();

    await tester.pumpWidget(
      MaterialApp(theme: lightMode, home: const ChatPrivacyPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });
}
