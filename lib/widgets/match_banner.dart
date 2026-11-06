import 'package:flutter/material.dart';
import 'package:palturo/widgets/app_banner.dart';

/// Builds the subtle top match banner used instead of a modal bottom sheet.
AppBannerData buildMatchBanner({
  required String id,
  required String name,
  required VoidCallback onSayHello,
  String? skillName,
  String? avatarUrl,
}) {
  final skill = skillName?.trim();
  return AppBannerData(
    id: id,
    groupKey: 'match:$id',
    title: "You're now Pals with $name",
    body:
        skill == null || skill.isEmpty
            ? 'Start the conversation when you are ready.'
            : 'Matched on $skill',
    icon: Icons.celebration_outlined,
    avatarUrl: avatarUrl,
    actorName: name,
    actionLabel: 'Say hello',
    onAction: onSayHello,
    onTap: onSayHello,
    duration: const Duration(seconds: 7),
    variant: AppBannerVariant.match,
  );
}
