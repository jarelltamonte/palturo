import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle title = TextStyle(
    fontFamily: 'Comfortaa',
    fontWeight: FontWeight.w700,
    fontSize: 40,
    color: AppColors.textPrimary,
  );

  static final TextStyle titleStroke = TextStyle(
    fontFamily: 'Comfortaa',
    fontWeight: FontWeight.w700,
    fontSize: 40,
    foreground: Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = AppColors.textPrimary, 
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: 'Comfortaa',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.textSecondary,
  );
}