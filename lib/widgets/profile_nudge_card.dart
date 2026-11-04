import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// Non-blocking profile completion nudge shown above the deck.
class ProfileNudgeCard extends StatelessWidget {
  const ProfileNudgeCard({
    super.key,
    required this.onLater,
    required this.onComplete,
  });

  final VoidCallback onLater;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: AppColors.accentText(context),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add a photo, bio, and languages so Pals can match with you.',
                  style: AppTextStyles.regularText.copyWith(
                    color: textColor,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              TextButton(onPressed: onLater, child: const Text('Later')),
              TextButton(
                onPressed: onComplete,
                child: const Text('Complete profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
