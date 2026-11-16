import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// Shared empty-state layout so Chats, Requests, and Activity agree on
/// illustration or icon size, text rhythm, and action placement.
class AppEmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showIllustration;

  /// A static icon used instead of the animated illustration.
  final IconData? icon;

  /// Space reserved under the content for the floating bottom navigation.
  final double bottomPadding;

  static const double illustrationSize = 200;
  static const double compactIllustrationSize = 120;

  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.showIllustration = true,
    this.icon,
    this.bottomPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, bottomPadding),
      child: Center(child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 16;
    final illustration = largeText ? compactIllustrationSize : illustrationSize;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIllustration) ...[
          Lottie.asset(
            'assets/lottie/empty.json',
            width: illustration,
            height: illustration,
            fit: BoxFit.contain,
            animate: !MediaQuery.disableAnimationsOf(context),
          ),
          const SizedBox(height: 8),
        ] else if (icon != null) ...[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.mutedSurface(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Icon(icon, size: 30, color: AppColors.mutedText(context)),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.boldText.copyWith(color: textColor),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppTextStyles.regularText.copyWith(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}
