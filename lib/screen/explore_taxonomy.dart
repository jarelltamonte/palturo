import 'package:flutter/material.dart';

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

/// Pastel tile behind a domain icon. Shared so a domain reads the same on
/// Browse and on its own page.
Color exploreTint(String path) {
  switch (path.split('.').first) {
    case 'agriculture_livelihood':
    case 'modern_practical_skills':
      return const Color(0xFFCFE8DA);
    case 'cooking_culinary':
    case 'traditional_crafts':
      return const Color(0xFFF3E1C7);
    case 'household_skills':
    case 'visual_arts_design':
      return const Color(0xFFF0D9BD);
    case 'language_writing':
    case 'performing_arts':
      return const Color(0xFFE3D9F2);
    case 'martial_arts':
      return const Color(0xFFF6D9D3);
    default:
      // Lime at 18%, matching AppColors.primary with alpha.
      return const Color(0x2EBFE109);
  }
}
