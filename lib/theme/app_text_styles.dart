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

  static const TextStyle regularText = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 16,
  );

  static const TextStyle boldText = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
    fontSize: 16,
  );

  static const TextStyle italicText = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.textPrimary,
    fontStyle: FontStyle.italic,
  );
}