import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_page.dart';
import 'package:palturo/theme/theme.dart';

ProfileData _profile({
  required OnboardingRole role,
  List<String> teachingStyles = const ['Hands-on Practice'],
}) {
  return ProfileData(
    name: 'Aling Rosa',
    schedule: 'Weekends',
    languages: const ['English'],
    interests: const ['Discussion'],
    teachingStyles: teachingStyles,
    role: role,
  );
}

Future<void> _pumpSummary(WidgetTester tester, ProfileData profile) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
}

void main() {
  test('fromMap reads the teaching styles array', () {
    final profile = ProfileData.fromMap({
      'id': 'u1',
      'first_name': 'Aling',
      'last_name': 'Rosa',
      'role': 'mentor',
      'availability': ['Monday'],
      'learning_styles': ['Video Tutorials'],
      'teaching_styles': ['Hands-on Practice', 'Discussion'],
    });

    expect(profile.interests, ['Video Tutorials']);
    expect(profile.teachingStyles, ['Hands-on Practice', 'Discussion']);
  });

  test('fromMap tolerates a missing teaching_styles column', () {
    final profile = ProfileData.fromMap({
      'id': 'u2',
      'first_name': 'Aling',
      'last_name': 'Rosa',
      'role': 'learner',
      'availability': ['Monday'],
    });

    expect(profile.teachingStyles, isEmpty);
  });

  testWidgets('mentor summary shows the teaching style', (tester) async {
    await _pumpSummary(tester, _profile(role: OnboardingRole.teach));

    expect(find.textContaining('Teaching style:'), findsOneWidget);
    expect(find.textContaining('Hands-on Practice'), findsOneWidget);
  });

  testWidgets('learner summary hides the teaching style', (tester) async {
    await _pumpSummary(tester, _profile(role: OnboardingRole.learn));

    expect(find.textContaining('Teaching style:'), findsNothing);
  });

  testWidgets('mentor without a teaching style shows no empty row', (
    tester,
  ) async {
    await _pumpSummary(
      tester,
      _profile(role: OnboardingRole.both, teachingStyles: const []),
    );

    expect(find.textContaining('Teaching style:'), findsNothing);
  });
}
