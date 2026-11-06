import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

enum AppFeedbackTone { info, success, error }

/// One snackbar contract for the app: dismiss the current message, keep one
/// action, and announce the text to assistive technology.
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
  AppFeedbackTone tone = AppFeedbackTone.info,
}) {
  showAppSnackBarOn(
    ScaffoldMessenger.of(context),
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
    tone: tone,
  );
}

void showAppSnackBarOn(
  ScaffoldMessengerState messenger,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
  AppFeedbackTone tone = AppFeedbackTone.info,
}) {
  messenger.clearSnackBars();
  final color =
      tone == AppFeedbackTone.error
          ? AppColors.dangerLight
          : tone == AppFeedbackTone.success
          ? AppColors.primary
          : AppColors.white;
  final icon =
      tone == AppFeedbackTone.error
          ? Icons.error_outline
          : tone == AppFeedbackTone.success
          ? Icons.check_circle_outline
          : Icons.info_outline;

  messenger.showSnackBar(
    SnackBar(
      duration:
          duration ??
          (tone == AppFeedbackTone.error
              ? const Duration(seconds: 6)
              : tone == AppFeedbackTone.success
              ? const Duration(seconds: 3)
              : const Duration(seconds: 4)),
      content: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      action:
          actionLabel != null && onAction != null
              ? SnackBarAction(label: actionLabel, onPressed: onAction)
              : null,
    ),
  );
}

void showAppSuccess(BuildContext context, String message) {
  showAppSnackBar(context, message, tone: AppFeedbackTone.success);
}

void showAppError(BuildContext context, String message) {
  showAppSnackBar(context, message, tone: AppFeedbackTone.error);
}

void showAppErrorOn(ScaffoldMessengerState messenger, String message) {
  showAppSnackBarOn(messenger, message, tone: AppFeedbackTone.error);
}
