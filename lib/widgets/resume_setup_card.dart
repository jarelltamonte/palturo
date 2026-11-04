import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// "Continue setup" card shown when an onboarding draft or a skipped setup
/// still exists. Dismissible without blocking the rest of the profile.
class ResumeSetupCard extends StatelessWidget {
  const ResumeSetupCard({
    super.key,
    required this.onTap,
    required this.onDismiss,
  });

  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline,
                color: AppColors.accentText(context),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue setup',
                      style: AppTextStyles.boldText.copyWith(
                        color: textColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add the details that power better matches.',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.mutedText(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Dismiss continue setup',
                onPressed: onDismiss,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.mutedText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
