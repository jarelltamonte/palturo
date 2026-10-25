import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import '../onboarding_controller.dart';
import '../onboarding_models.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingReviewScreen extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onSave;
  final VoidCallback? onBack;
  final VoidCallback onEditRole;
  final VoidCallback onEditLearning;
  final VoidCallback onEditTeaching;
  final VoidCallback onEditDetails;
  final String stepLabel;
  final VoidCallback? onSkip;

  const OnboardingReviewScreen({
    super.key,
    required this.controller,
    required this.onSave,
    this.onBack,
    required this.onEditRole,
    required this.onEditLearning,
    required this.onEditTeaching,
    required this.onEditDetails,
    this.stepLabel = 'Step 4 of 4 - Review',
    this.onSkip,
  });

  String _roleLabel(OnboardingRole? role) => switch (role) {
    OnboardingRole.learn => 'Learner',
    OnboardingRole.teach => 'Mentor',
    OnboardingRole.both => 'Learner and mentor',
    null => 'Not set',
  };

  String _pretty(String id) {
    return id
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _skills(Set<String> ids) {
    if (ids.isEmpty) return 'Not set';
    return ids.map(_pretty).join(', ');
  }

  bool get _isValid =>
      controller.role != null &&
      (!controller.wantsLearning || controller.learningInterests.isNotEmpty) &&
      (!controller.wantsTeaching || controller.teachingInterests.isNotEmpty) &&
      controller.learningStyles.isNotEmpty &&
      controller.languages.isNotEmpty &&
      controller.availabilityDays.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return OnboardingScaffold(
      title: 'Review your profile',
      subtitle: 'Check your setup before saving.',
      stepLabel: stepLabel,
      progress: 1,
      showBackButton: true,
      onBack: onBack,
      primaryLabel: 'Save and continue',
      onPrimaryPressed: _isValid ? onSave : null,
      onSkip: onSkip,
      showSkip: true,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (!_isValid) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'Add your role, availability, language, and learning style to save.',
                style: AppTextStyles.regularText.copyWith(
                  color: textColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          _ReviewSection(
            title: 'Role',
            value: _roleLabel(controller.role),
            onEdit: onEditRole,
          ),
          if (controller.wantsLearning)
            _ReviewSection(
              title: 'Learning interests',
              value: _skills(controller.learningInterests),
              onEdit: onEditLearning,
            ),
          if (controller.wantsTeaching)
            _ReviewSection(
              title: 'Teaching interests',
              value: _skills(controller.teachingInterests),
              onEdit: onEditTeaching,
            ),
          _ReviewSection(
            title: 'Availability',
            value:
                controller.availabilityDays.isEmpty
                    ? 'Not set'
                    : controller.availabilityDays.join(', '),
            onEdit: onEditDetails,
          ),
          _ReviewSection(
            title: 'Languages',
            value:
                controller.languages.isEmpty
                    ? 'Not set'
                    : controller.languages.join(', '),
            onEdit: onEditDetails,
          ),
          _ReviewSection(
            title: 'Learning style',
            value:
                controller.learningStyles.isEmpty
                    ? 'Not set'
                    : controller.learningStyles.join(', '),
            onEdit: onEditDetails,
          ),
          const SizedBox(height: 8),
          Text(
            'You can change any of this later from Profile.',
            style: AppTextStyles.regularText.copyWith(
              color: AppColors.mutedText(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ready to meet your first Pal?',
            style: AppTextStyles.regularText.copyWith(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onEdit;

  const _ReviewSection({
    required this.title,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.regularText.copyWith(
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}
