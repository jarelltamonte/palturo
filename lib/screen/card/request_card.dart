import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

class RequestCard extends StatelessWidget {
  final String skillName;
  final String requesterName;
  final String schedule;
  final String language;
  final String learningStyle;
  final String timeAgo;
  final String iconAsset;
  final String seekingLabel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const RequestCard({
    super.key,
    required this.skillName,
    required this.requesterName,
    required this.schedule,
    required this.language,
    required this.learningStyle,
    required this.timeAgo,
    this.iconAsset = 'assets/icons/rlearner.svg',
    this.seekingLabel = 'Seeking a learner in',
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(iconAsset, width: 22, height: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  seekingLabel,
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_up, color: textTheme),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  skillName,
                  style: AppTextStyles.boldText.copyWith(
                    color: primaryColor,
                    fontSize: 20,
                  ),
                ),
              ),
              Text(
                timeAgo,
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 0.5,
            color: textTheme.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8E8E8),
                ),
                child: const Icon(Icons.person, size: 28, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requesterName,
                      style: AppTextStyles.boldText.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: textTheme,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              schedule,
                              style: AppTextStyles.regularText.copyWith(
                                color: textTheme,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.translate, size: 13, color: textTheme),
                            const SizedBox(width: 4),
                            Text(
                              language,
                              style: AppTextStyles.regularText.copyWith(
                                color: textTheme,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.psychology, size: 13, color: textTheme),
                            const SizedBox(width: 4),
                            Text(
                              learningStyle,
                              style: AppTextStyles.regularText.copyWith(
                                color: textTheme,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onAccept,
                  child: Text(
                    'Accept',
                    style: AppTextStyles.regularText.copyWith(
                      color: primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: AppColors.black.withValues(alpha: 0.2),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onDecline,
                  child: Text(
                    'Decline',
                    style: AppTextStyles.regularText.copyWith(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
