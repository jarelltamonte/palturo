import 'package:flutter/material.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_select_field.dart';

const kLearningStyleOptions = [
  'Visual Demonstration',
  'Discussion',
  'Hands-on Practice',
  'Reading Materials',
  'Video Tutorials',
];

const kDayOptions = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const kLanguageOptions = ['English', 'Filipino', 'Bisaya', 'Ilocano'];

class OnboardingFinalScreen extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onDone;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const OnboardingFinalScreen({
    super.key,
    required this.controller,
    required this.onDone,
    this.onBack,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isValid = controller.learningStyles.isNotEmpty &&
            controller.availabilityDays.isNotEmpty &&
            controller.languages.isNotEmpty;

        return OnboardingScaffold(
          title: 'One last thing',
          subtitle: 'Help us personalize your matches by adding one final detail.',
          progress: 0.9,
          showBackButton: true,
          onBack: onBack,
          primaryLabel: 'Done',
          onPrimaryPressed: isValid ? onDone : null,
          onSkip: onSkip,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OnboardingSelectField(
                  label: 'Learning Style',
                  labelIcon: Icons.psychology,
                  hint: 'Select your learning style',
                  displayValue: controller.learningStyles.join(', '),
                  options: kLearningStyleOptions,
                  selected: controller.learningStyles,
                  multiSelect: true,
                  onChanged: controller.setLearningStyles,
                ),
                const SizedBox(height: 24),
                OnboardingSelectField(
                  label: 'Availability',
                  labelIcon: Icons.calendar_today_rounded,
                  hint: 'Select your availability',
                  displayValue: controller.availabilityDays.join(', '),
                  options: kDayOptions,
                  selected: controller.availabilityDays,
                  multiSelect: true,
                  onChanged: controller.setAvailabilityDays,
                ),
                const SizedBox(height: 16),
                OnboardingSelectField(
                  label: 'Language Preference',
                  labelIcon: Icons.translate,
                  hint: 'Select your language preference',
                  displayValue: controller.languages.join(', '),
                  options: kLanguageOptions,
                  selected: controller.languages,
                  multiSelect: true,
                  onChanged: controller.setLanguages,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}