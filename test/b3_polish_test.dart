import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:palturo/onboarding/onboarding_flow.dart';
import 'package:palturo/screen/home_page.dart';
import 'package:palturo/screen/profile_page.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/resume_setup_card.dart';

void main() {
  test('onboarding draft keys are scoped per signed-in user', () {
    expect(onboardingDraftKey(null), 'onboarding_draft');
    expect(onboardingDraftKey('user-1'), 'onboarding_draft_user-1');
    expect(onboardingDraftKey('user-1'), isNot(onboardingDraftKey('user-2')));
  });

  test(
    'resume card shows for skipped or drafted onboarding unless dismissed',
    () {
      expect(
        shouldShowResumeCard(
          skipped: false,
          dismissed: false,
          hasDraft: false,
          setupComplete: false,
        ),
        isFalse,
      );
      expect(
        shouldShowResumeCard(
          skipped: true,
          dismissed: false,
          hasDraft: false,
          setupComplete: false,
        ),
        isTrue,
      );
      expect(
        shouldShowResumeCard(
          skipped: false,
          dismissed: false,
          hasDraft: true,
          setupComplete: false,
        ),
        isTrue,
      );
      expect(
        shouldShowResumeCard(
          skipped: true,
          dismissed: true,
          hasDraft: true,
          setupComplete: false,
        ),
        isFalse,
      );
      expect(
        shouldShowResumeCard(
          skipped: true,
          dismissed: false,
          hasDraft: true,
          setupComplete: true,
        ),
        isFalse,
      );
    },
  );

  test('dismissal keys are scoped per user', () {
    expect(onboardingResumeDismissedKey(null), 'onboarding_resume_dismissed');
    expect(
      onboardingResumeDismissedKey('user-1'),
      'onboarding_resume_dismissed_user-1',
    );
    expect(profileNudgeDismissedKey(null), 'profile_nudge_dismissed');
    expect(
      profileNudgeDismissedKey('user-1'),
      'profile_nudge_dismissed_user-1',
    );
  });

  testWidgets('resume card opens and dismisses at 200% text', (tester) async {
    var opened = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightMode,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Center(
              child: ResumeSetupCard(
                onTap: () => opened++,
                onDismiss: () => dismissed++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Continue setup'), findsOneWidget);

    await tester.tap(find.text('Continue setup'));
    expect(opened, 1);

    await tester.tap(find.byTooltip('Dismiss continue setup'));
    expect(dismissed, 1);
    expect(tester.takeException(), isNull);
  });
}
