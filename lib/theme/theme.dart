import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';

ThemeData _baseTheme({
  required Brightness brightness,
  required Color surface,
  required Color onSurface,
}) {
  final isDark = brightness == Brightness.dark;
  final accentText = isDark ? AppColors.primary : AppColors.accentTextLight;
  final border = isDark ? AppColors.borderDark : AppColors.borderLight;
  final scheme =
      isDark
          ? ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.black,
            secondary: onSurface,
            onSecondary: AppColors.black,
            error: AppColors.danger,
            onError: AppColors.white,
            surface: surface,
            onSurface: onSurface,
          )
          : ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.black,
            secondary: onSurface,
            onSecondary: AppColors.white,
            error: AppColors.danger,
            onError: AppColors.white,
            surface: surface,
            onSurface: onSurface,
          );

  final radius = BorderRadius.circular(24);

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    fontFamily: 'Inter',
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 0.5, space: 16),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor:
          isDark ? AppColors.inputBackground : AppColors.binputBackground,
      hintStyle: TextStyle(
        color: onSurface.withValues(alpha: 0.45),
        fontFamily: 'Inter',
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.black,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radius),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentText,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentText,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? AppColors.elevatedDark : AppColors.background,
      contentTextStyle: const TextStyle(
        color: AppColors.white,
        fontFamily: 'Inter',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

ThemeData lightMode = _baseTheme(
  brightness: Brightness.light,
  surface: AppColors.white,
  onSurface: AppColors.textSecondary,
);

ThemeData darkMode = _baseTheme(
  brightness: Brightness.dark,
  surface: AppColors.background,
  onSurface: AppColors.textPrimary,
);
