import 'onboarding_models.dart';

/// The selectable skill layer.
///
/// Selections stop at depth 2 of the taxonomy. Depth 3 stays in the database
/// for search aliases, showcase captions, and matching focus, but users are
/// never asked to pick an oddly specific leaf such as a single dish.
const kSelectableSkills = <OnboardingOption>[
  // Agriculture & Livelihood
  OnboardingOption('farming', 'Farming'),
  OnboardingOption('fishing', 'Fishing'),
  OnboardingOption('local_trades', 'Local Trades'),
  // Cooking & Culinary
  OnboardingOption('filipino_dessert_making', 'Filipino Dessert Making'),
  OnboardingOption('filipino_cooking', 'Filipino Cooking'),
  // Household Skills
  OnboardingOption('home_decorating', 'Home Decorating'),
  OnboardingOption('kitchen_basics', 'Kitchen Basics'),
  // Language & Writing
  OnboardingOption('calligraphy', 'Calligraphy'),
  OnboardingOption('philippine_script_writing', 'Philippine Script Writing'),
  // Martial Arts
  OnboardingOption('filipino_martial_arts', 'Filipino Martial Arts'),
  // Modern Practical Skills
  OnboardingOption('flairtending', 'Flairtending'),
  OnboardingOption('graphic_design', 'Graphic Design'),
  OnboardingOption('motorcycle_maintenance', 'Motorcycle Maintenance'),
  OnboardingOption('nail_art', 'Nail Art'),
  OnboardingOption('programming', 'Programming'),
  OnboardingOption('sewing', 'Sewing'),
  OnboardingOption('tshirt_printing', 'T-Shirt Printing'),
  OnboardingOption('woodworking', 'Woodworking'),
  // Performing Arts
  OnboardingOption('folk_dance', 'Folk Dance'),
  OnboardingOption('traditional_music', 'Traditional Music'),
  OnboardingOption('vocal_music', 'Vocal Music'),
  // Traditional Crafts
  OnboardingOption('costume_making', 'Costume Making'),
  OnboardingOption('filipino_embroidery', 'Filipino Embroidery'),
  OnboardingOption('parol_lantern_making', 'Parol & Lantern Making'),
  OnboardingOption('philippine_handweaving', 'Philippine Handweaving'),
  // Visual Arts & Design
  OnboardingOption('painting', 'Painting'),
  OnboardingOption('others', 'Others'),
];

/// The four broad buckets used by profile matching, mapped from the depth-2
/// taxonomy node ids.
const Map<String, String> kSkillToCategorySlug = {
  'farming': 'agriculture_livelihood',
  'fishing': 'agriculture_livelihood',
  'local_trades': 'agriculture_livelihood',

  'filipino_dessert_making': 'everyday_skills',
  'filipino_cooking': 'everyday_skills',
  'home_decorating': 'everyday_skills',
  'kitchen_basics': 'everyday_skills',
  'filipino_martial_arts': 'everyday_skills',
  'flairtending': 'everyday_skills',
  'graphic_design': 'everyday_skills',
  'motorcycle_maintenance': 'everyday_skills',
  'nail_art': 'everyday_skills',
  'programming': 'everyday_skills',
  'sewing': 'everyday_skills',
  'tshirt_printing': 'everyday_skills',
  'woodworking': 'everyday_skills',

  'calligraphy': 'language_culture',
  'philippine_script_writing': 'language_culture',
  'folk_dance': 'language_culture',
  'traditional_music': 'language_culture',
  'vocal_music': 'language_culture',

  'costume_making': 'arts_design',
  'filipino_embroidery': 'arts_design',
  'parol_lantern_making': 'arts_design',
  'philippine_handweaving': 'arts_design',
  'painting': 'arts_design',
};

/// Drafts and cached selections can still carry the pre-rename ids. Map them
/// so a resumed onboarding keeps the user's choices.
const Map<String, String> kLegacySkillIdAliases = {
  'filipino_mains': 'filipino_cooking',
  'filipino_desserts_kakanin': 'filipino_dessert_making',
  'kitchen_skills': 'kitchen_basics',
  'philippine_scripts': 'philippine_script_writing',
};

const Map<String, String> kLegacySkillLabelAliases = {
  'filipino mains': 'filipino_cooking',
  'filipino desserts & kakanin': 'filipino_dessert_making',
  'kitchen skills': 'kitchen_basics',
  'philippine scripts': 'philippine_script_writing',
};

String? selectableSkillLabelForId(String id) {
  final canonical = kLegacySkillIdAliases[id] ?? id;
  for (final option in kSelectableSkills) {
    if (option.id == canonical) return option.label;
  }
  return null;
}

List<String> resolveCategoriesForSkills(Iterable<String> skills) {
  final categories = <String>{};
  for (final raw in skills) {
    final value = raw.trim();
    if (value.isEmpty) continue;

    final lower = value.toLowerCase();
    final canonicalId =
        kLegacySkillIdAliases[lower] ?? kLegacySkillLabelAliases[lower];
    final direct = kSkillToCategorySlug[canonicalId ?? lower];
    if (direct != null) {
      categories.add(direct);
      continue;
    }

    final normalized = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final bySlug =
        kSkillToCategorySlug[kLegacySkillIdAliases[normalized] ?? normalized];
    if (bySlug != null) {
      categories.add(bySlug);
      continue;
    }

    for (final option in kSelectableSkills) {
      if (option.label.toLowerCase() == lower) {
        final category = kSkillToCategorySlug[option.id];
        if (category != null) categories.add(category);
        break;
      }
    }
  }
  return categories.toList();
}
