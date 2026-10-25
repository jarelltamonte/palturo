import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/widgets/user_avatar.dart';

enum RequestMatchAction { sayHello, keepBrowsing }

Future<RequestMatchAction?> showRequestMatchSheet(
  BuildContext context, {
  required String name,
  String? skillName,
  ImageProvider? avatarImage,
}) {
  return showModalBottomSheet<RequestMatchAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => RequestMatchSheet(
          name: name,
          skillName: skillName,
          avatarImage: avatarImage,
        ),
  );
}

class RequestMatchSheet extends StatelessWidget {
  final String name;
  final String? skillName;
  final ImageProvider? avatarImage;

  const RequestMatchSheet({
    super.key,
    required this.name,
    this.skillName,
    this.avatarImage,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final hasSkill = skillName != null && skillName!.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            UserAvatar(name: name, image: avatarImage, size: 78),
            const SizedBox(height: 14),
            Text(
              'You are now Pals with $name',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingText.copyWith(
                color: textColor,
                fontSize: 20,
              ),
            ),
            if (hasSkill) ...[
              const SizedBox(height: 8),
              Text(
                'Matched on $skillName',
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.mutedText(context),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        () => Navigator.pop(
                          context,
                          RequestMatchAction.keepBrowsing,
                        ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 48),
                      side: BorderSide(color: AppColors.border(context)),
                    ),
                    child: const Text('Keep browsing'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        () =>
                            Navigator.pop(context, RequestMatchAction.sayHello),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 48),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Say hello'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
