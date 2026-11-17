import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';

/// Icon per taxonomy root path. Shared by Browse and the Explore feed so the
/// same category always reads the same way.
const Map<String, IconData> exploreRootIcons = {
  'cooking_culinary': Icons.restaurant_outlined,
  'traditional_crafts': Icons.palette_outlined,
  'performing_arts': Icons.music_note_outlined,
  'martial_arts': Icons.sports_martial_arts,
  'language_writing': Icons.translate,
  'household_skills': Icons.home_repair_service_outlined,
  'agriculture_livelihood': Icons.agriculture_outlined,
  'modern_practical_skills': Icons.handyman_outlined,
  'visual_arts_design': Icons.brush_outlined,
};

IconData exploreRootIcon(String path) {
  final root = path.split('.').first;
  return exploreRootIcons[root] ?? Icons.category_outlined;
}

/// Tile behind a domain icon. One brand-green tint everywhere so the cards
/// read as one system instead of a pastel palette.
Color exploreTileTint(BuildContext context) =>
    AppColors.primary.withValues(alpha: 0.18);
