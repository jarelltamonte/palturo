import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.white, 
  colorScheme: ColorScheme.light(
    surface: AppColors.white,
    primary: AppColors.textSecondary,
    secondary: AppColors.textSecondary,
    onPrimary: AppColors.secondary,
  ),
);

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.dark(
    surface: AppColors.background,
    primary: AppColors.primary,
    secondary: AppColors.textPrimary,
    onPrimary: AppColors.inputBackground,
  ),
);
