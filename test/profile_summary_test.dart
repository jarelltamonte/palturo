import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_page.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/user_avatar.dart';

void main() {
  testWidgets('long profile names clamp and the avatar is 72px', (
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

  testWidgets('the summary shows the bio and the derived role chips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ProfileData(
      name: 'Pal Tester',
      schedule: 'Weekends',
      bio: 'I teach adobo and want to learn weaving.',
      languages: const ['English'],
      interests: const ['Hands-on Practice'],
      role: OnboardingRole.learn,
      learningSkillIds: const ['weaving'],
      teachingSkillIds: const ['cooking'],
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

    expect(
      find.text('I teach adobo and want to learn weaving.'),
      findsOneWidget,
    );
    // Skills imply the role, even when the stored role is stale.
    expect(find.text('Learner'), findsOneWidget);
    expect(find.text('Mentor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a complete profile shows a tappable check next to the name', (
    tester,
  ) async {
    var opened = 0;
    final profile = ProfileData(
      name: 'Pal Tester',
      schedule: 'Weekends',
      languages: const ['English'],
      interests: const ['Hands-on Practice'],
      role: OnboardingRole.learn,
      learningSkillIds: const ['weaving'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileSummaryCard(
              profile: profile,
              onTap: () => opened++,
              onAvatarTap: () {},
              isComplete: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pump();

    expect(find.text('Profile Complete'), findsOneWidget);
    expect(opened, 0);
  });

  testWidgets('incomplete profiles have no completion check', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileSummaryCard(
              profile: ProfileData(
                name: 'Pal Tester',
                schedule: 'Weekends',
                languages: const ['English'],
              ),
              onTap: () {},
              onAvatarTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsNothing);
  });
}
