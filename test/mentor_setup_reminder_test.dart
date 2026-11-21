import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/mentor_setup_reminder.dart';

Widget _host(
  ProfileData? profile, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) {
  return MaterialApp(
    theme: lightMode,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: MentorSetupReminder(profileLoader: () async => profile),
      ),
    ),
  );
}

ProfileData _mentor({
  Map<String, String> notes = const {},
  Map<String, bool> approvedNotes = const {},
  Set<String> approvedSkills = const {'barong_embroidery'},
  Map<String, String> images = const {},
  Map<String, String> reviewStatus = const {},
}) {
  return ProfileData(
    schedule: 'Not set',
    role: OnboardingRole.teach,
    teachingSkillIds: const ['barong_embroidery'],
    approvedTeachingSkills: approvedSkills,
    teachingNotes: notes,
    teachingNoteApproved: approvedNotes,
    noteReviewStatus: reviewStatus,
    teachingSkillImages: images,
    notesLoaded: true,
    hasCompletedOnboarding: true,
    languages: const ['English'],
    availableDays: const ['Friday'],
  );
}

void main() {
  testWidgets('shows the missing showcase and notes with a progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_mentor()));
    await tester.pumpAndSettle();

    expect(find.text('Mentor setup'), findsOneWidget);
    expect(find.text('Showcase + notes'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 0);
  });

  testWidgets('hides when the mentor side is ready', (tester) async {
    await tester.pumpWidget(
      _host(
        _mentor(
          notes: const {'barong_embroidery': 'Hands-on and patient.'},
          approvedNotes: const {'barong_embroidery': true},
          images: const {'barong_embroidery': 'https://x.test/a.jpg'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mentor setup'), findsNothing);
  });

  testWidgets('shows notes under review', (tester) async {
    await tester.pumpWidget(
      _host(
        _mentor(
          notes: const {'barong_embroidery': 'Hands-on and patient.'},
          approvedNotes: const {'barong_embroidery': false},
          images: const {'barong_embroidery': 'https://x.test/a.jpg'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notes in review'), findsOneWidget);
  });

  testWidgets('shows a flagged teaching note instead of review copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _mentor(
          notes: const {'barong_embroidery': 'Hands-on and patient.'},
          approvedNotes: const {'barong_embroidery': false},
          images: const {'barong_embroidery': 'https://x.test/a.jpg'},
          reviewStatus: const {'teach|barong_embroidery': 'rejected'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fix flagged notes'), findsOneWidget);
  });

  testWidgets('shows a pending teaching skill', (tester) async {
    await tester.pumpWidget(_host(_mentor(approvedSkills: const {})));
    await tester.pumpAndSettle();

    expect(find.text('Skill in review'), findsOneWidget);
  });

  testWidgets('progress reflects the showcase requirement', (tester) async {
    await tester.pumpWidget(
      _host(
        _mentor(images: const {'barong_embroidery': 'https://x.test/a.jpg'}),
      ),
    );
    await tester.pumpAndSettle();

    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 0.5);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Teaching notes'), findsOneWidget);
  });

  testWidgets('fits a narrow viewport at 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(_mentor(), size: const Size(320, 640), textScale: 2),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mentor setup'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final title = tester.renderObject<RenderParagraph>(
      find.text('Mentor setup'),
    );
    final body = tester.renderObject<RenderParagraph>(
      find.text('Showcase + notes'),
    );
    expect(title.didExceedMaxLines, isFalse);
    expect(body.didExceedMaxLines, isFalse);
  });

  testWidgets('a save during the first load triggers a reload', (tester) async {
    final revision = ProfileService.profileRevision.value;
    addTearDown(() => ProfileService.profileRevision.value = revision);
    var calls = 0;
    final first = Completer<ProfileData?>();

    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: Scaffold(
          body: MentorSetupReminder(
            profileLoader: () {
              calls++;
              if (calls == 1) return first.future;
              return Future.value(
                _mentor(
                  notes: const {'barong_embroidery': 'Hands-on and patient.'},
                  approvedNotes: const {'barong_embroidery': true},
                  images: const {'barong_embroidery': 'https://x.test/a.jpg'},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    ProfileService.profileRevision.value++;
    first.complete(_mentor());
    await tester.pumpAndSettle();

    expect(calls, greaterThanOrEqualTo(2));
    expect(find.text('Mentor setup'), findsNothing);
  });
}
