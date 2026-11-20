import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// Full-screen indicator shown while the review step saves the new profile.
///
/// First-time profile creation places skills, writes embeddings, and warms
/// matching, so it can take noticeably longer than a normal save. The copy
/// keeps changing once the wait is long enough to look stuck.
class OnboardingSaveOverlay extends StatelessWidget {
  const OnboardingSaveOverlay({super.key, required this.slow});

  /// True once the save has run long enough that a user may think it stalled.
  final bool slow;

  static const String title = 'Saving your profile…';
  static const String body =
      'Setting up your skills and matches for the first time.';
  static const String slowBody =
      'This can take a little longer for a new profile. Please keep this '
      'screen open — we are still working.';

  @override
  Widget build(BuildContext context) {
    final message = slow ? slowBody : body;
    return Container(
      color: Colors.black45,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Semantics(
            liveRegion: true,
            label: '$title $message',
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.boldText.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.mutedText(context),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
