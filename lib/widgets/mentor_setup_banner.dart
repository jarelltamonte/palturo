import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// Persistent reminder that a mentor is still hidden from discovery.
///
/// The backend only shows the mentor side once a showcase exists and every
/// teaching skill has an approved note. This banner stays on Home until then.
class MentorSetupBanner extends StatelessWidget {
  const MentorSetupBanner({
    super.key,
    required this.needsShowcase,
    required this.needsNotes,
    required this.notesPendingReview,
    required this.skillPendingReview,
    required this.onTap,
  });

  final bool needsShowcase;
  final bool needsNotes;
  final bool notesPendingReview;
  final bool skillPendingReview;
  final VoidCallback onTap;

  String get _body {
    if (skillPendingReview) return 'Skill in review';
    if (notesPendingReview) return 'Notes in review';
    if (needsShowcase && needsNotes) return 'Showcase + notes';
    if (needsNotes) return 'Teaching notes';
    return 'Showcase';
  }

  String get _semanticsBody {
    if (skillPendingReview) {
      return 'Your teaching skill is still under review.';
    }
    if (notesPendingReview) {
      return 'Your teaching notes are under review.';
    }
    if (needsShowcase && needsNotes) {
      return 'A showcase and teaching notes are needed.';
    }
    if (needsNotes) return 'Teaching notes are needed.';
    return 'A showcase is needed.';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final accent = AppColors.accentText(context);

    return Semantics(
      container: true,
      button: true,
      label: 'Finish your mentor setup. $_semanticsBody',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mentor setup',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.boldText.copyWith(
                        color: textColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.regularText.copyWith(
                        color: textColor.withValues(alpha: 0.75),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
