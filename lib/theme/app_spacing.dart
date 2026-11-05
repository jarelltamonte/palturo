import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared spacing and chrome tokens. New page chrome should use these instead
/// of ad-hoc values so titles and trailing actions line up across screens.
class AppSpacing {
  static const double pageHorizontal = 16;
  static const double iconTarget = 48;
  static const double leadingWidth = 48;
  static const double titleSpacing = 16;
  static const double trailingInset = 16;

  /// Bottom padding for a scroll view under the floating tab bar. Inside the
  /// shell, Scaffold already reports the nav height in `padding.bottom`
  /// (extendBody), so add only the 16 px breathing room.
  static double bottomNavClearanceFor(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 16;

  /// Content height for the editable onboarding role cards. The card is
  /// content-sized above this floor, never stretched to the page height.
  static const double onboardingRoleCardHeight = 168;

  /// Height of the single selected role card in read-only/review mode.
  static const double onboardingRoleCardCompactHeight = 44;

  static double topBarHeight() =>
      defaultTargetPlatform == TargetPlatform.iOS ? iconTarget : 56;
}
