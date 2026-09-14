import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../onboarding_controller.dart';
import '../widgets/availability_row.dart';
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

  Future<TimeOfDay?> _pickTime(BuildContext context,
      {required TimeOfDay initialTime, String? helpText}) {
    if (_isCupertino) {
      return _showCupertinoTimePicker(context,
          initialTime: initialTime, title: helpText);
    }
    return showTimePicker(
        context: context, initialTime: initialTime, helpText: helpText);
  }

  Future<TimeOfDay?> _showCupertinoTimePicker(
    BuildContext context, {
    required TimeOfDay initialTime,
    String? title,
  }) {
    var selected = initialTime;
    final initialDateTime = DateTime(
        2022, 1, 1, initialTime.hour, initialTime.minute);
    final secondary = Theme.of(context).colorScheme.secondary;

    return showCupertinoModalPopup<TimeOfDay>(
      context: context,
      builder: (context) => Container(
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

  Future<void> _pickTimeRange(BuildContext context, String day) async {
    final start = await _pickTime(
      context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Start time',
    );
    if (start == null || !context.mounted) return;

    final end = await _pickTime(
      context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
      helpText: 'End time',
    );
    if (end == null || !context.mounted) return;

    controller.setAvailability(
      day,
      '${start.format(context)} - ${end.format(context)}',
    );
  }

  void _addAvailabilityRow(BuildContext context) {
    final unusedDay = kDayOptions.firstWhere(
      (d) => !controller.availability.containsKey(d),
      orElse: () => kDayOptions.first,
    );
    controller.setAvailability(unusedDay, 'Tap to set time');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final days = controller.availability.keys.toList();
        final isValid = controller.learningStyles.isNotEmpty &&
            controller.availability.isNotEmpty &&
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
                  hint: 'Select your learning style',
                  displayValue: controller.learningStyles.join(', '),
                  options: kLearningStyleOptions,
                  selected: controller.learningStyles,
                  multiSelect: true,
                  onChanged: controller.setLearningStyles,
                ),
                const SizedBox(height: 24),
                Text(
                  'Availability',
                  style: AppTextStyles.regularText.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final day in days)
                  AvailabilityRow(
                    day: day,
                    timeRange: controller.availability[day] ?? 'Tap to set time',
                    dayOptions: kDayOptions,
                    onDayChanged: (newDay) {
                      final range = controller.availability[day] ?? '';
                      controller.removeAvailability(day);
                      controller.setAvailability(newDay, range);
                    },
                    onTimeTap: () => _pickTimeRange(context, day),
                    onRemove: () => controller.removeAvailability(day),
                  ),
                TextButton.icon(
                  onPressed: () => _addAvailabilityRow(context),
                  icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                  label: Text(
                    'Add',
                    style: AppTextStyles.regularText
                        .copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                OnboardingSelectField(
                  label: 'Language Preference',
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