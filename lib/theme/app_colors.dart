import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF262626);
  static const Color inputBackground = Color(0xFF2A2A2A);
  static const Color binputBackground = Color(0xFFF3F4F6);

  static const Color primary = Color(0xFFBFE109);
  static const Color secondary = Color(0xFFBCBCBC);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF262626);

  /// Derived tokens. These keep the lime brand fill intact while giving text
  /// and muted controls enough contrast on light surfaces.
  static const Color accentTextLight = Color(0xFF5F7300);
  static const Color mutedTextLight = Color(0xFF5C6B73);
  static const Color mutedTextDark = secondary;

  static const Color elevatedLight = Color(0xFFFFFFFF);
  static const Color elevatedDark = Color(0xFF303030);
  static const Color mutedSurfaceLight = Color(0xFFF5F5F5);
  static const Color mutedSurfaceDark = Color(0xFF333333);
  static const Color borderLight = Color(0xFFE2E2E2);
  static const Color borderDark = Color(0xFF3D3D3D);
  static const Color switchOffTrackLight = Color(0xFF666666);
  static const Color switchOffTrackDark = switchOffTrackLight;

  static const Color white = Colors.white;
  static const Color black = Colors.black;

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color accentText(BuildContext context) =>
      _isDark(context) ? primary : accentTextLight;

  static Color mutedText(BuildContext context) =>
      _isDark(context) ? mutedTextDark : mutedTextLight;

  static Color elevatedSurface(BuildContext context) =>
      _isDark(context) ? elevatedDark : elevatedLight;

  static Color mutedSurface(BuildContext context) =>
      _isDark(context) ? mutedSurfaceDark : mutedSurfaceLight;

  static Color border(BuildContext context) =>
      _isDark(context) ? borderDark : borderLight;

  static Color switchOffTrack(BuildContext context) =>
      _isDark(context) ? switchOffTrackDark : switchOffTrackLight;
}
