import 'package:flutter/material.dart';
import 'package:palturo/screen/utils/schedule_format.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
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

/// Teaching styles use the same vocabulary as learning styles: they describe
/// how a mentor runs a session, and they are only collected for mentors.
const kTeachingStyleOptions = kLearningStyleOptions;

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
  final double progress;

  const OnboardingFinalScreen({
    super.key,
    required this.controller,
    required this.onDone,
    this.onBack,
    this.progress = 0.85,
  });

  void _setAvailableDays(Set<String> days) {
    controller.setAvailabilityDays(days);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selectedDays =
            kDayOptions.where(controller.availabilityDays.contains).toList();

        final wantsLearning = controller.wantsLearning;
        final wantsTeaching = controller.wantsTeaching;
        final isValid =
            (!wantsLearning || controller.learningStyles.isNotEmpty) &&
            (!wantsTeaching || controller.teachingStyles.isNotEmpty) &&
            controller.languages.isNotEmpty &&
            selectedDays.isNotEmpty;

        return OnboardingScaffold(
          title: 'One last thing',
          subtitle:
              'Help us personalize your matches by adding one final detail.',
          stepLabel: '',
          progress: progress,
          showBackButton: true,
          onBack: onBack,
          primaryLabel: 'Review',
          onPrimaryPressed: isValid ? onDone : null,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OnboardingSelectField(
                  label: 'Learning Style',
                  labelIconAsset: 'assets/icons/rlearner.svg',
                  hint: 'Select your learning style',
                  displayValue: controller.learningStyles.join(', '),
                  options: kLearningStyleOptions,
                  selected: controller.learningStyles,
                  multiSelect: true,
                  onChanged: controller.setLearningStyles,
                ),
                if (controller.wantsTeaching) ...[
                  const SizedBox(height: 24),
                  OnboardingSelectField(
                    label: 'Teaching Style',
                    labelIconAsset: 'assets/icons/rmentor.svg',
                    hint: 'Select your teaching style',
                    displayValue: controller.teachingStyles.join(', '),
                    options: kTeachingStyleOptions,
                    selected: controller.teachingStyles,
                    multiSelect: true,
                    onChanged: controller.setTeachingStyles,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You will add your showcase after saving. It is what '
                          'makes you visible to learners.',
                          style: AppTextStyles.regularText.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                OnboardingSelectField(
                  label: 'Availability',
                  labelIcon: Icons.calendar_today_rounded,
                  hint: 'Select the days you\'re available',
                  displayValue: formatScheduleDays(selectedDays),
                  options: kDayOptions,
                  selected: selectedDays.toSet(),
                  multiSelect: true,
                  onChanged: _setAvailableDays,
                ),
                const SizedBox(height: 24),
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
