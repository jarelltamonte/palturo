import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_page.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/user_avatar.dart';

void main() {
  testWidgets('long profile names clamp and the avatar is 72px', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ProfileData(
      name: 'VisualAudit TwentyFive Char Name',
      schedule: 'Weekends',
      languages: const ['English'],
      interests: const ['Cooking'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileSummaryCard(
              profile: profile,
              onTap: () {},
              onAvatarTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final name = tester.widget<Text>(find.text(profile.name));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);

    final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
    expect(avatar.size, 72);

    expect(find.text('Edit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header survives 200% text with the edit action reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ProfileData(
      name: 'VisualAudit TwentyFive Char Name',
      schedule: 'Weekends',
      languages: const ['English'],
      interests: const ['Cooking'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileSummaryCard(
              profile: profile,
              onTap: () {},
              onAvatarTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
