import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../onboarding_models.dart';

class RoleCardGroup extends StatelessWidget {
  final List<RoleOption> options;
  final OnboardingRole? selected;
  final ValueChanged<OnboardingRole> onSelect;

  const RoleCardGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _RoleCard(
                option: option,
                selected: selected == option.role,
                onTap: () => onSelect(option.role),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final RoleOption option;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.textSecondary : Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 120,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : fg.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(option.icon, color: fg),
            const SizedBox(height: 8),
            Text(
              option.label,
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
