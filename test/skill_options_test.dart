import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_flow.dart'
    show kLearningOptions, kTeachingOptions;
import 'package:palturo/onboarding/skill_options.dart';

void main() {
  test('onboarding offers the depth-2 layer, not single dishes', () {
    final labels = kLearningOptions.map((o) => o.label).toList();

    expect(labels, contains('Filipino Mains'));
    expect(labels, contains('Filipino Desserts & Kakanin'));
    expect(labels, contains('Filipino Embroidery'));
    expect(labels, contains('Programming'));
    expect(labels, contains('Sewing'));
    expect(labels, isNot(contains('Cooking Pinakbet')));
    expect(labels, isNot(contains('Barong Embroidery')));
    expect(kTeachingOptions, same(kLearningOptions));
  });

  test('every selectable option maps to one of the four match buckets', () {
    for (final option in kSelectableSkills) {
      if (option.id == 'others') continue;
      expect(
        kSkillToCategorySlug.containsKey(option.id),
        isTrue,
        reason: '${option.label} has no category mapping',
      );
    }
  });

  test('labels and ids both resolve to a category', () {
    expect(resolveCategoriesForSkills(['filipino_mains']), ['everyday_skills']);
    expect(
      resolveCategoriesForSkills(['Filipino Desserts & Kakanin']),
      ['everyday_skills'],
    );
    expect(resolveCategoriesForSkills(['Programming']), ['everyday_skills']);
    expect(resolveCategoriesForSkills(['Farming']), ['agriculture_livelihood']);
    expect(resolveCategoriesForSkills(['Filipino Embroidery']), ['arts_design']);
    expect(resolveCategoriesForSkills(['Vocal Music']), ['language_culture']);
  });

  test('option ids resolve back to their labels', () {
    expect(selectableSkillLabelForId('filipino_mains'), 'Filipino Mains');
    expect(selectableSkillLabelForId('programming'), 'Programming');
    expect(selectableSkillLabelForId('missing'), isNull);
  });
}
