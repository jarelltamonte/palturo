import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_select_field.dart';

bool get _isCupertino =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

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

  Future<TimeOfDay?> _pickTime(
    BuildContext context, {
    required TimeOfDay initialTime,
    String? helpText,
  }) {
    if (_isCupertino) {
      return _showCupertinoTimePicker(
        context,
        initialTime: initialTime,
        title: helpText,
      );
    }
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
    );
  }

  Future<TimeOfDay?> _showCupertinoTimePicker(
    BuildContext context, {
    required TimeOfDay initialTime,
    String? title,
  }) {
    var selected = initialTime;
    final initialDateTime = DateTime(
      2022,
      1,
      1,
      initialTime.hour,
      initialTime.minute,
    );
    final secondary = Theme.of(context).colorScheme.secondary;

    return showCupertinoModalPopup<TimeOfDay>(
      context: context,
      builder:
          (context) => Container(
            height: 260,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      Text(
                        title ?? 'Time',
                        style: AppTextStyles.boldText.copyWith(
                          color: secondary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      CupertinoButton(
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: initialDateTime,
                      use24hFormat: false,
                      onDateTimeChanged: (newTime) {
                        selected = TimeOfDay.fromDateTime(newTime);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  String _formatDays(List<String> days) {
    final set = days.toSet();
    const weekdays = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
    const weekend = {'Saturday', 'Sunday'};

    if (set.length == 7) return 'Everyday';
    if (set.length == weekdays.length && set.containsAll(weekdays)) {
      return 'Weekdays';
    }
    if (set.length == weekend.length && set.containsAll(weekend)) {
      return 'Weekend';
    }
    return days.map((d) => d.substring(0, 3)).join('/');
  }

  void _setAvailableDays(Set<String> days) {
    final existing = controller.availability.keys.toList();

    for (final day in existing) {
      if (!days.contains(day)) {
        controller.removeAvailability(day);
      }
    }
    for (final day in days) {
      if (!controller.availability.containsKey(day)) {
        controller.setAvailability(day, '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selectedDays =
            kDayOptions.where(controller.availability.containsKey).toList();

        final isValid =
            controller.learningStyles.isNotEmpty &&
            controller.languages.isNotEmpty &&
            selectedDays.isNotEmpty;

        return OnboardingScaffold(
          title: 'One last thing',
          subtitle:
              'Help us personalize your matches by adding one final detail.',
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
                  hint: 'Select the days you\'re available',
                  displayValue: _formatDays(selectedDays),
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