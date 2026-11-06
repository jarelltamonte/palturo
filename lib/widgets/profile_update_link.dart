import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

class ProfileUpdateLink extends StatelessWidget {
  final VoidCallback onTap;

  const ProfileUpdateLink({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(
        'Update your profile',
        style: AppTextStyles.regularText.copyWith(
          color: AppColors.accentText(context),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationThickness: 1.5,
        ),
      ),
    );
  }
}
