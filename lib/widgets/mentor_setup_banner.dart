import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// Persistent reminder that a mentor is still hidden from discovery.
///
/// The backend only shows the mentor side once a showcase exists and every
/// teaching skill has an approved note. This banner appears on Activity until
/// then.
class MentorSetupBanner extends StatelessWidget {
  const MentorSetupBanner({
    super.key,
    required this.needsShowcase,
    required this.needsNotes,
    required this.notesPendingReview,
    required this.notesRejected,
    required this.skillPendingReview,
    required this.progress,
    required this.onTap,
  });

  final bool needsShowcase;
  final bool needsNotes;
  final bool notesPendingReview;
  final bool notesRejected;
  final bool skillPendingReview;
  final double progress;
  final VoidCallback onTap;

  String get _body {
    if (notesRejected) return 'Fix flagged notes';
    if (skillPendingReview) return 'Skill in review';
    if (notesPendingReview) return 'Notes in review';
    if (needsShowcase && needsNotes) return 'Showcase + notes';
    if (needsNotes) return 'Teaching notes';
    return 'Showcase';
  }

  String get _semanticsBody {
    if (notesRejected) {
      return 'A teaching note was flagged. Update it to make your mentor side '
          'visible.';
    }
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
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    final danger = AppColors.dangerText(context);
    final fillColor = notesRejected ? danger : AppColors.primary;
    final accentColor = notesRejected ? danger : accent;
    final titleColor = notesRejected ? danger : textColor;
    final bodyColor =
        notesRejected
            ? danger.withValues(alpha: 0.85)
            : textColor.withValues(alpha: 0.75);

    return Semantics(
      container: true,
      button: true,
      label: 'Finish your mentor setup, $percent percent. $_semanticsBody',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: fillColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fillColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: fillColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(fillColor, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/images/triangle.png',
                      fit: BoxFit.contain,
                    ),
                  ),
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
                        color: titleColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: AppColors.progressTrack(context),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                fillColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$percent%',
                          style: AppTextStyles.boldText.copyWith(
                            color: accentColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.regularText.copyWith(
                        color: bodyColor,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}
