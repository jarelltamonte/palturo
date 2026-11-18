import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_flow.dart'
    show kLearningOptions, kTeachingOptions;
import 'package:palturo/onboarding/skill_options.dart';

void main() {
  test('onboarding offers the selectable skill layer, not single dishes', () {
    final labels = kLearningOptions.map((o) => o.label).toList();

    expect(labels, contains('Filipino Cooking'));
    expect(labels, contains('Filipino Dessert Making'));
    expect(labels, contains('Filipino Embroidery'));
    expect(labels, contains('General Programming'));
    expect(labels, contains('Python Programming'));
    expect(labels, contains('C# Programming'));
    expect(labels, contains('Web Development'));
    expect(labels, isNot(contains('Programming')));
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
    expect(resolveCategoriesForSkills(['filipino_cooking']), [
      'everyday_skills',
    ]);
    expect(resolveCategoriesForSkills(['Filipino Dessert Making']), [
      'everyday_skills',
    ]);
    expect(resolveCategoriesForSkills(['Python Programming']), [
      'everyday_skills',
    ]);
    expect(resolveCategoriesForSkills(['Farming']), ['agriculture_livelihood']);
    expect(resolveCategoriesForSkills(['Filipino Embroidery']), [
      'arts_design',
    ]);
    expect(resolveCategoriesForSkills(['Vocal Music']), ['language_culture']);
  });

  test('option ids resolve back to their labels', () {
    expect(selectableSkillLabelForId('filipino_cooking'), 'Filipino Cooking');
    expect(
      selectableSkillLabelForId('python_programming'),
      'Python Programming',
    );
    expect(selectableSkillLabelForId('c_sharp_programming'), 'C# Programming');
    expect(selectableSkillLabelForId('missing'), isNull);
  });

  test('paths resolve a selectable id at any depth', () {
    expect(
      selectableSkillIdForPath(
        'modern_practical_skills.programming.python_programming',
      ),
      'python_programming',
    );
    expect(
      selectableSkillIdForPath(
        'modern_practical_skills.programming.c_sharp_programming',
      ),
      'c_sharp_programming',
    );
    // A focus leaf still resolves to its parent skill.
    expect(
      selectableSkillIdForPath(
        'cooking_culinary.filipino_cooking.sourdough_baking',
      ),
      'filipino_cooking',
    );
    expect(selectableSkillIdForPath('unknown.category.leaf'), isNull);
  });

  test('custom onboarding ids decode to their label', () {
    expect(
      onboardingInterestLabel('other:onboarding:Sourdough Baking'),
      'Sourdough Baking',
    );
    expect(onboardingInterestLabel('other:arts_design:Parol Art'), 'Parol Art');
    expect(onboardingInterestLabel('filipino_cooking'), 'Filipino Cooking');
    expect(onboardingInterestLabel('others'), 'Others');
  });
}

