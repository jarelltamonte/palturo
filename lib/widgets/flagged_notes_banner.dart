import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// Red reminder that a note was rejected and needs the author's attention.
class FlaggedNotesBanner extends StatelessWidget {
  const FlaggedNotesBanner({
    super.key,
    required this.skills,
    required this.onTap,
  });

  final List<String> skills;
  final VoidCallback onTap;

  String get _body {
    if (skills.length > 1) {
      return 'Update ${skills.length} flagged notes.';
    }
    return 'Update your flagged note.';
  }

  String get _semanticsBody =>
      'Flagged notes: ${skills.join(', ')}. Open Profile to update.';

  @override
  Widget build(BuildContext context) {
    final danger = AppColors.dangerText(context);
    final textColor = Theme.of(context).colorScheme.secondary;

    return Semantics(
      container: true,
      button: true,
      label: 'A note needs attention. $_semanticsBody',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: danger.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: danger.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.flag_outlined, size: 18, color: danger),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A note needs attention',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.boldText.copyWith(
                        color: danger,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.regularText.copyWith(
                        color: textColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: danger),
            ],
          ),
        ),
      ),
    );
  }
}
