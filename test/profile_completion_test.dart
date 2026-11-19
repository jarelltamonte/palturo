import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/services/profile_service.dart';

void main() {
  test('fromMap drops null and blank skill entries', () {
    final profile = ProfileData.fromMap({
      'id': 'profile-1',
      'teaching_skills': ['Programming', null, '   '],
      'learning_skills': null,
      'languages': ['English', null],
      'learning_styles': ['Visual Demonstration', ''],
    });
    expect(profile.teachingSkillIds, ['Programming']);
    expect(profile.learningSkillIds, isEmpty);
    expect(profile.languages, ['English']);
    expect(profile.interests, ['Visual Demonstration']);
  });

  test('setup and showcase needs follow role, skills, and media', () {
    final empty = ProfileData(schedule: '', role: OnboardingRole.learn);
    expect(empty.needsSetup, isTrue);
    expect(empty.needsShowcase, isFalse);

    final learner = empty.copyWith(learningSkillIds: const ['programming']);
    expect(learner.needsSetup, isFalse);

    final mentor = ProfileData(
      schedule: '',
      role: OnboardingRole.teach,
      teachingSkillIds: const ['filipino_cooking'],
    );
    expect(mentor.needsSetup, isFalse);
    expect(mentor.needsShowcase, isTrue);

    final withShowcase = mentor.copyWith(
      teachingSkillImages: const {
        'Filipino Cooking': 'https://x.test/showcase.mp4',
      },
    );
    expect(withShowcase.needsShowcase, isFalse);
  });

  test('requires every profile field and a role skill', () {
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const ['Visual'],
        teachingStyles: const [],
        role: OnboardingRole.learn,
        hasRoleSkills: true,
      ),
      isTrue,
    );
    expect(
      isProfileComplete(
        avatarUrl: null,
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const ['Visual'],
        teachingStyles: const [],
        role: OnboardingRole.learn,
        hasRoleSkills: true,
      ),
      isFalse,
    );
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: '   ',
        languages: const ['English'],
        learningStyles: const ['Visual'],
        teachingStyles: const [],
        role: OnboardingRole.learn,
        hasRoleSkills: true,
      ),
      isFalse,
    );
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const [],
        learningStyles: const ['Visual'],
        teachingStyles: const [],
        role: OnboardingRole.learn,
        hasRoleSkills: true,
      ),
      isFalse,
    );
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const [],
        teachingStyles: const [],
        role: OnboardingRole.learn,
        hasRoleSkills: true,
      ),
      isFalse,
    );
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const ['Visual'],
        teachingStyles: const [],
        role: OnboardingRole.learn,
        hasRoleSkills: false,
      ),
      isFalse,
    );
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const ['Visual'],
        teachingStyles: const [],
        role: OnboardingRole.learn,
        hasRoleSkills: true,
        hasShowcase: false,
      ),
      isFalse,
    );
  });
  test('role-specific styles are required', () {
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const [],
        teachingStyles: const ['Visual'],
        role: OnboardingRole.teach,
        hasRoleSkills: true,
      ),
      isTrue,
    );
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const ['Visual'],
        teachingStyles: const [],
        role: OnboardingRole.teach,
        hasRoleSkills: true,
      ),
      isFalse,
    );
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const [],
        teachingStyles: const ['Visual'],
        role: OnboardingRole.learn,
        hasRoleSkills: true,
      ),
      isFalse,
    );
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const ['Visual'],
        teachingStyles: const [],
        role: OnboardingRole.both,
        hasRoleSkills: true,
      ),
      isFalse,
    );
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const ['Visual'],
        teachingStyles: const ['Visual'],
        role: OnboardingRole.both,
        hasRoleSkills: true,
      ),
      isTrue,
    );
  });
}
