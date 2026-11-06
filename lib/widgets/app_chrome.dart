import 'package:flutter/material.dart';
import 'package:palturo/theme/app_spacing.dart';

/// Shared top-bar helpers. The app uses one trailing inset and one action
/// target so the right side of every page lines up.
class AppChrome {
  static AppBar appBar({
    Widget? leading,
    Widget? title,
    List<Widget>? actions,
    bool centerTitle = false,
    Color? backgroundColor,
    double? toolbarHeight,
    double? titleSpacing,
  }) {
    return AppBar(
      toolbarHeight: toolbarHeight ?? AppSpacing.topBarHeight(),
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      centerTitle: centerTitle,
      leadingWidth: leading == null ? null : AppSpacing.leadingWidth,
      leading: leading,
      titleSpacing: title == null ? 0 : (titleSpacing ?? AppSpacing.titleSpacing),
      title: title,
      actions: actions,
      actionsPadding:
          actions == null
              ? null
              : const EdgeInsets.only(right: AppSpacing.trailingInset),
    );
  }

  static Widget iconAction({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    Color? color,
    double size = 24,
    Widget? child,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: AppSpacing.iconTarget,
        height: AppSpacing.iconTarget,
      ),
      icon:
          child ??
          Icon(icon, size: size, color: color),
    );
  }

  static Widget backButton(BuildContext context, {Color? color}) {
    return iconAction(
      icon: Icons.arrow_back_ios_new,
      tooltip: 'Back',
      onPressed: () => Navigator.pop(context),
      color: color,
      size: 16,
    );
  }
}
