import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../onboarding_models.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RoleCardGroup extends StatelessWidget {
  final List<RoleOption> options;
  final OnboardingRole? selected;
  final ValueChanged<OnboardingRole> onSelect;
  final bool isEditing;

  const RoleCardGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.isEditing = true,
  });

  @override
  Widget build(BuildContext context) {
    final visibleOptions = isEditing
        ? options
        : options.where((o) => o.role == selected).toList();
    final isCompact = visibleOptions.length == 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in visibleOptions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _RoleCard(
                option: option,
                selected: selected == option.role,
                compact: isCompact,
                isEditing: isEditing,
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
  final bool compact;
  final bool isEditing;
  final VoidCallback onTap;

  const _RoleCard({
    required this.option,
    required this.selected,
    required this.compact,
    required this.isEditing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppColors.textSecondary
        : Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTap: isEditing ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: compact ? 56 : 120,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : fg.withValues(alpha: 0.5),
          ),
        ),
        child: compact
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    option.iconAsset,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    option.label.replaceAll('\n', ' '),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.regularText.copyWith(color: fg),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    option.iconAsset,
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                  ),
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