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
  OnboardingOption('filipino_desserts_kakanin', 'Filipino Desserts & Kakanin'),
  OnboardingOption('filipino_mains', 'Filipino Mains'),
  // Household Skills
  OnboardingOption('home_decorating', 'Home Decorating'),
  OnboardingOption('kitchen_skills', 'Kitchen Skills'),
  // Language & Writing
  OnboardingOption('calligraphy', 'Calligraphy'),
  OnboardingOption('philippine_scripts', 'Philippine Scripts'),
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

  'filipino_desserts_kakanin': 'everyday_skills',
  'filipino_mains': 'everyday_skills',
  'home_decorating': 'everyday_skills',
  'kitchen_skills': 'everyday_skills',
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
  'philippine_scripts': 'language_culture',
  'folk_dance': 'language_culture',
  'traditional_music': 'language_culture',
  'vocal_music': 'language_culture',

  'costume_making': 'arts_design',
  'filipino_embroidery': 'arts_design',
  'parol_lantern_making': 'arts_design',
  'philippine_handweaving': 'arts_design',
  'painting': 'arts_design',
};

String? selectableSkillLabelForId(String id) {
  for (final option in kSelectableSkills) {
    if (option.id == id) return option.label;
  }
  return null;
}

List<String> resolveCategoriesForSkills(Iterable<String> skills) {
  final categories = <String>{};
  for (final raw in skills) {
    final value = raw.trim();
    if (value.isEmpty) continue;

    final direct = kSkillToCategorySlug[value.toLowerCase()];
    if (direct != null) {
      categories.add(direct);
      continue;
    }

    final normalized = value.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    final bySlug = kSkillToCategorySlug[normalized];
    if (bySlug != null) {
      categories.add(bySlug);
      continue;
    }

    for (final option in kSelectableSkills) {
      if (option.label.toLowerCase() == value.toLowerCase()) {
        final category = kSkillToCategorySlug[option.id];
        if (category != null) categories.add(category);
        break;
      }
    }
  }
  return categories.toList();
}
