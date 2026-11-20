import 'package:flutter/material.dart';
import 'package:palturo/models/profile_completion.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// A progress meter that tells the user what is still missing from their
/// profile. Tapping the action opens the editor; the labels are the guidance.
class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({
    super.key,
    required this.completion,
    required this.onEdit,
    this.compact = false,
    this.showAction = true,
  });

  final ProfileCompletion completion;
  final VoidCallback onEdit;
  final bool compact;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final muted = AppColors.mutedText(context);
    final accent = AppColors.accentText(context);
    final fill = AppColors.primary;
    final complete = completion.isComplete;
    final missing = completion.missing.take(4).toList(growable: false);
    final extra = completion.remainingCount - missing.length;

    return Semantics(
      container: true,
      label:
          'Profile completion ${completion.percent} percent. '
          '${complete ? 'Complete.' : '${completion.remainingCount} details left.'}',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                complete
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.border(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: fill.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    complete ? Icons.check_circle_outline : Icons.donut_large,
                    size: 18,
                    color: complete ? AppColors.successText(context) : fill,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Profile completion',
                    style: AppTextStyles.boldText.copyWith(
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${completion.percent}%',
                  style: AppTextStyles.headingText.copyWith(
                    color: complete ? AppColors.successText(context) : accent,
                    fontSize: 18,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completion.fraction,
                minHeight: 8,
                backgroundColor: AppColors.progressTrack(context),
                valueColor: AlwaysStoppedAnimation<Color>(fill),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              complete
                  ? 'Everything is filled in. Nice work.'
                  : '${completion.remainingCount} '
                      '${completion.remainingCount == 1 ? 'detail' : 'details'} '
                      'left. A complete profile helps people find and trust you.',
              style: AppTextStyles.regularText.copyWith(
                color: muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (!complete && missing.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final item in missing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.radio_button_unchecked,
                          size: 13,
                          color: fill,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: AppTextStyles.regularText.copyWith(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item.detail,
                              style: AppTextStyles.regularText.copyWith(
                                color: muted,
                                fontSize: 10.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (extra > 0)
                Text(
                  '+$extra more',
                  style: AppTextStyles.regularText.copyWith(
                    color: muted,
                    fontSize: 11,
                  ),
                ),
              if (showAction) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: Icon(Icons.edit_outlined, size: 16, color: fill),
                  label: Text(
                    'Finish profile',
                    style: AppTextStyles.regularText.copyWith(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
