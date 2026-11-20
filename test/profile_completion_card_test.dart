import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/models/profile_completion.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/profile_completion_card.dart';

ProfileCompletion _completion({required bool complete}) {
  return computeProfileCompletion(
    ProfileData(
      schedule: '',
      role: OnboardingRole.learn,
      bio: complete ? 'Hello' : '',
      photos: complete ? const ['https://example.test/me.jpg'] : const [null],
      languages: complete ? const ['English'] : const [],
      availableDays: complete ? const ['Friday'] : const [],
      interests: complete ? const ['Hands-on Practice'] : const [],
      learningSkillIds: complete ? const ['cooking'] : const [],
      age: complete ? 29 : null,
      gender: complete ? 'woman' : null,
    ),
  );
}

Widget _host(
  Widget child, {
  double scale = 1,
  Size size = const Size(390, 844),
}) {
  return MaterialApp(
    theme: lightMode,
    home: MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets(
    'incomplete profile shows progress, missing parts, and guidance',
    (tester) async {
      var edited = 0;
      await tester.pumpWidget(
        _host(
          ProfileCompletionCard(
            completion: _completion(complete: false),
            onEdit: () => edited++,
          ),
        ),
      );

      expect(find.text('Profile completion'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Profile photo'), findsOneWidget);
      expect(find.text('Finish profile'), findsOneWidget);
      await tester.tap(find.text('Finish profile'));
      expect(edited, 1);
    },
  );

  testWidgets('complete profile shows the success state', (tester) async {
    await tester.pumpWidget(
      _host(
        ProfileCompletionCard(
          completion: _completion(complete: true),
          onEdit: () {},
        ),
      ),
    );
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Everything is filled in. Nice work.'), findsOneWidget);
    expect(find.text('Finish profile'), findsNothing);
  });

  testWidgets('fits a small phone at 200% text', (tester) async {
    await tester.pumpWidget(
      _host(
        ProfileCompletionCard(
          completion: _completion(complete: false),
          onEdit: () {},
        ),
        scale: 2,
        size: const Size(360, 640),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Profile completion'), findsOneWidget);
  });
}
