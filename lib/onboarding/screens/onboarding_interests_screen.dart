import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../onboarding_models.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingInterestsScreen extends StatelessWidget {
  final String highlightWord;
  final List<OnboardingOption> options;
  final Set<String> selected;
  final int maxSelections;
  final ValueChanged<String> onToggle;
  final double progress;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String stepLabel;

  const OnboardingInterestsScreen({
    super.key,
    required this.highlightWord,
    required this.options,
    required this.selected,
    required this.maxSelections,
    required this.onToggle,
    required this.progress,
    required this.onContinue,
    this.onBack,
    this.onSkip,
    this.stepLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final canProceed = selected.isNotEmpty;
    final atLimit = selected.length >= maxSelections;

    return OnboardingScaffold(
      title: 'What are you interested in $highlightWord',
      highlightWord: highlightWord,
      highlightColor: AppColors.primary,
      subtitle: 'Select up to $maxSelections that apply',
      progress: progress,
      showBackButton: true,
      onBack: onBack,
      onSkip: onSkip,
      onPrimaryPressed: canProceed ? onContinue : null,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _InterestChip(
                  label: option.label,
                  selected: selected.contains(option.id),
                  dimmed: atLimit && !selected.contains(option.id),
                  onTap: () => onToggle(option.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _InterestChip({
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final fg = selected ? AppColors.textSecondary : secondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.5 : 1,
        child: Material(
          color: selected ? AppColors.primary : Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border(context),
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            splashFactory: NoSplash.splashFactory,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.regularText.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}