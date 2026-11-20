import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/models/profile_completion.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/profile_data.dart';

ProfileData _profile({
  OnboardingRole? role,
  String bio = '',
  List<String?> photos = const [null, null, null],
  List<String> languages = const [],
  List<String> days = const [],
  List<String> interests = const [],
  List<String> teachingStyles = const [],
  List<String> learningSkills = const [],
  List<String> teachingSkills = const [],
  Map<String, String> showcases = const {},
  int? age,
  String? gender,
}) {
  return ProfileData(
    schedule: '',
    role: role,
    bio: bio,
    photos: photos,
    languages: languages,
    availableDays: days,
    interests: interests,
    teachingStyles: teachingStyles,
    learningSkillIds: learningSkills,
    teachingSkillIds: teachingSkills,
    teachingSkillImages: showcases,
    age: age,
    gender: gender,
  );
}

void main() {
  test('an empty profile has zero completion and lists the missing parts', () {
    final completion = computeProfileCompletion(_profile());
    expect(completion.percent, 0);
    expect(completion.isComplete, isFalse);
    expect(
      completion.missing.map((item) => item.label),
      contains('Profile photo'),
    );
    expect(
      completion.missing.map((item) => item.label),
      contains('Role and skills'),
    );
    expect(completion.missing.map((item) => item.label), contains('Age'));
    expect(completion.missing.map((item) => item.label), contains('Gender'));
  });

  test('a complete learner profile reaches 100 percent', () {
    final completion = computeProfileCompletion(
      _profile(
        role: OnboardingRole.learn,
        bio: 'Hello',
        photos: const ['https://example.test/me.jpg'],
        languages: const ['English'],
        days: const ['Friday'],
        interests: const ['Hands-on Practice'],
        learningSkills: const ['cooking'],
        age: 29,
        gender: 'woman',
      ),
    );
    expect(completion.percent, 100);
    expect(completion.isComplete, isTrue);
    expect(completion.missing, isEmpty);
  });

  test('a mentor needs a teaching style and a showcase', () {
    final missingShowcase = computeProfileCompletion(
      _profile(
        role: OnboardingRole.teach,
        bio: 'Hello',
        photos: const ['https://example.test/me.jpg'],
        languages: const ['English'],
        days: const ['Friday'],
        interests: const ['Hands-on Practice'],
        teachingStyles: const ['Discussion'],
        teachingSkills: const ['weaving'],
        age: 40,
        gender: 'man',
      ),
    );
    expect(missingShowcase.percent, lessThan(100));
    expect(
      missingShowcase.missing.map((item) => item.label),
      contains('Showcase'),
    );

    final complete = computeProfileCompletion(
      _profile(
        role: OnboardingRole.teach,
        bio: 'Hello',
        photos: const ['https://example.test/me.jpg'],
        languages: const ['English'],
        days: const ['Friday'],
        interests: const ['Hands-on Practice'],
        teachingStyles: const ['Discussion'],
        teachingSkills: const ['weaving'],
        showcases: const {'weaving': 'https://example.test/weave.jpg'},
        age: 40,
        gender: 'man',
      ),
    );
    expect(complete.percent, 100);
    expect(complete.isComplete, isTrue);
  });
}
