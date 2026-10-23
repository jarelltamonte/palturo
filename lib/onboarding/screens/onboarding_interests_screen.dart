import 'package:flutter/material.dart';
import '../onboarding_models.dart';
import '../widgets/chip_selector.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final canProceed = selected.isNotEmpty;

    return OnboardingScaffold(
      title: 'What are you interested in $highlightWord?',
      highlightWord: highlightWord,
      subtitle: 'Select up to $maxSelections that apply',
      progress: progress,
      showBackButton: true,
      onBack: onBack,
      onSkip: onSkip,
      onPrimaryPressed: canProceed ? onContinue : null,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: ChipSelector(
          options: options,
          selected: selected,
          maxSelections: maxSelections,
          onToggle: onToggle,
        ),
      ),
    );
  }
}
