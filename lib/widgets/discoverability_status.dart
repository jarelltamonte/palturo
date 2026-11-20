import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// A high-visibility status card for mentor discoverability.
///
/// The backend treats a mentor as discoverable when at least one showcase
/// exists. Per-skill missing showcases are shown as a quality nudge, not as a
/// second hard gate.
class DiscoverabilityStatusCard extends StatelessWidget {
  const DiscoverabilityStatusCard({
    super.key,
    required this.wantsTeaching,
    required this.hasAnyShowcase,
    required this.missingSkillLabels,
    this.onAction,
    this.compact = false,
  });

  final bool wantsTeaching;
  final bool hasAnyShowcase;
  final List<String> missingSkillLabels;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!wantsTeaching) return const SizedBox.shrink();

    final complete = hasAnyShowcase && missingSkillLabels.isEmpty;
    final hidden = !hasAnyShowcase;
    final accent = complete ? AppColors.success : AppColors.accentText(context);
    final fill = AppColors.primary;
    final textColor = Theme.of(context).colorScheme.secondary;
    final muted = AppColors.mutedText(context);

    final title =
        complete
            ? 'You are visible in discovery'
            : hidden
            ? 'You are hidden from discovery'
            : '${missingSkillLabels.length} teaching '
                '${missingSkillLabels.length == 1 ? 'skill needs' : 'skills need'} '
                'a showcase';

    final body =
        complete
            ? 'Every teaching skill has a showcase. Learners can find you in '
                'For You, Browse, and Explore.'
            : hidden
            ? 'Add at least one photo or short video to a teaching skill. '
                'Learners cannot find you in For You, Browse, or Explore '
                'until you do.'
            : 'You are visible, but these skills still have no showcase. '
                'Add one to each so every card shows what you can teach.';

    final shownSkills = missingSkillLabels.take(3).toList(growable: false);
    final extra = missingSkillLabels.length - shownSkills.length;

    return Semantics(
      container: true,
      label: '$title. $body',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color:
              complete
                  ? fill.withValues(alpha: 0.1)
                  : fill.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: fill.withValues(alpha: complete ? 0.45 : 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 34 : 38,
                  height: compact ? 34 : 38,
                  decoration: BoxDecoration(
                    color: fill.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    complete
                        ? Icons.check_circle_outline
                        : hidden
                        ? Icons.visibility_off_outlined
                        : Icons.auto_awesome_outlined,
                    size: compact ? 18 : 20,
                    color: complete ? AppColors.success : fill,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.boldText.copyWith(
                          color: textColor,
                          fontSize: compact ? 13 : 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: AppTextStyles.regularText.copyWith(
                          color: muted,
                          fontSize: compact ? 11.5 : 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!complete && shownSkills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in shownSkills)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: fill.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label,
                        style: AppTextStyles.regularText.copyWith(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (extra > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: fill.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+$extra more',
                        style: AppTextStyles.regularText.copyWith(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (!complete && onAction != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  alignment: Alignment.centerLeft,
                ),
                icon: Icon(Icons.video_library_outlined, size: 17, color: fill),
                label: Text(
                  hidden ? 'Add a showcase' : 'Review teaching skills',
                  style: AppTextStyles.regularText.copyWith(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
