import 'onboarding_models.dart';

/// The selectable skill layer.
///
/// Selections target the selectable `kind='skill'` nodes: mostly depth 2, plus
/// the four depth-3 Programming skills. Deeper focus leaves stay in the
/// database for search aliases, showcase captions, and matching specificity,
/// but users are never asked to pick an oddly specific leaf such as a dish.
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
  // Programming is a category; these are the selectable skills under it.
  OnboardingOption('general_programming', 'General Programming'),
  OnboardingOption('python_programming', 'Python Programming'),
  OnboardingOption('c_sharp_programming', 'C# Programming'),
  OnboardingOption('web_development', 'Web Development'),
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

/// The taxonomy root each selectable skill belongs to.
///
/// Keys are the selectable (depth-2) ids; values are the root category paths
/// used by Browse, the profile card, and `profiles.skill_categories`.
const Map<String, String> kSkillToCategorySlug = {
  'farming': 'agriculture_livelihood',
  'fishing': 'agriculture_livelihood',
  'local_trades': 'agriculture_livelihood',

  'filipino_dessert_making': 'cooking_culinary',
  'filipino_cooking': 'cooking_culinary',

  'home_decorating': 'household_skills',
  'kitchen_basics': 'household_skills',

  'calligraphy': 'language_writing',
  'philippine_script_writing': 'language_writing',

  'filipino_martial_arts': 'martial_arts',

  'flairtending': 'modern_practical_skills',
  'graphic_design': 'modern_practical_skills',
  'motorcycle_maintenance': 'modern_practical_skills',
  'nail_art': 'modern_practical_skills',
  'general_programming': 'modern_practical_skills',
  'python_programming': 'modern_practical_skills',
  'c_sharp_programming': 'modern_practical_skills',
  'web_development': 'modern_practical_skills',
  'sewing': 'modern_practical_skills',
  'tshirt_printing': 'modern_practical_skills',
  'woodworking': 'modern_practical_skills',

  'folk_dance': 'performing_arts',
  'traditional_music': 'performing_arts',
  'vocal_music': 'performing_arts',

  'costume_making': 'traditional_crafts',
  'filipino_embroidery': 'traditional_crafts',
  'parol_lantern_making': 'traditional_crafts',
  'philippine_handweaving': 'traditional_crafts',

  'painting': 'visual_arts_design',
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

/// The depth-2 option id for a canonical skill name, if one exists.
///
/// The classifier returns the node it matched, which may be a depth-3 leaf
/// such as `Sourdough Baking`. This maps that name back to the selectable
/// depth-2 chip.
String? selectableSkillIdForLabel(String label) {
  final value = label.trim().toLowerCase();
  if (value.isEmpty) return null;
  for (final option in kSelectableSkills) {
    if (option.label.toLowerCase() == value) return option.id;
  }
  return null;
}

/// The selectable option id encoded in a taxonomy path.
///
/// Skills may live at any depth (`...programming.python_programming`), so the
/// leaf segment is checked first, then any ancestor for legacy paths such as
/// `cooking_culinary.filipino_cooking.sourdough_baking`.
String? selectableSkillIdForPath(String path) {
  final parts = path.split('.').where((part) => part.isNotEmpty).toList();
  for (final raw in parts.reversed) {
    final candidate = kLegacySkillIdAliases[raw] ?? raw;
    for (final option in kSelectableSkills) {
      if (option.id == candidate) return option.id;
    }
  }
  return null;
}

/// The label sent to `save_user_skills` for an onboarding selection.
///
/// Custom options encode their text in the id, for example
/// `other:onboarding:Sourdough Baking`.
String onboardingInterestLabel(String id) {
  if (id.toLowerCase() == 'others') return 'Others';
  if (id.startsWith('other:')) {
    final parts = id.split(':');
    if (parts.length >= 3) {
      final label = parts.sublist(2).join(':').trim();
      if (label.isNotEmpty) return label;
    }
  }
  final known = selectableSkillLabelForId(id);
  if (known != null) return known;
  return id
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
