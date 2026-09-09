import 'package:flutter/material.dart';
import 'package:palturo/models/onboarding_item.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardItemWidget extends StatelessWidget {
  const OnboardItemWidget({super.key, required this.item});

  final OnboardItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 20,
      children: [
        SvgPicture.asset(item.svg, width: 40),
        Lottie.asset(item.lottieUrl),
        Text(
          item.title,
          style: AppTextStyles.headingText.copyWith(color: Theme.of(context).colorScheme.secondary),
        ),
        const SizedBox(height: 16),

        Text(
          item.description,
          style: AppTextStyles.regularText.copyWith(color: Theme.of(context).colorScheme.secondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}