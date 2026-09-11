import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../onboarding_models.dart';

class ChipSelector extends StatelessWidget {
  final List<OnboardingOption> options;
  final Set<String> selected;
  final int maxSelections;
  final ValueChanged<String> onToggle;

  const ChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.maxSelections,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in options)
          _Chip(
            label: option.label,
            selected: selected.contains(option.id),
            disabled: !selected.contains(option.id) &&
                selected.length >= maxSelections,
            onTap: () => onToggle(option.id),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.textSecondary : Theme.of(context).colorScheme.secondary;
    
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : fg.withValues(alpha: disabled ? 0.15 : 0.3),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.regularText.copyWith(
            color: selected
                ? AppColors.textSecondary
                : fg.withValues(alpha: disabled ? 0.35 : 1),
          ),
        ),
      ),
    );
  }
}
