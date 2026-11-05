import 'package:flutter/foundation.dart';

/// Shared spacing and chrome tokens. New page chrome should use these instead
/// of ad-hoc values so titles and trailing actions line up across screens.
class AppSpacing {
  static const double pageHorizontal = 16;
  static const double iconTarget = 48;
  static const double leadingWidth = 48;
  static const double titleSpacing = 16;
  static const double trailingInset = 16;

  static double topBarHeight() =>
      defaultTargetPlatform == TargetPlatform.iOS ? 44 : 56;
}
