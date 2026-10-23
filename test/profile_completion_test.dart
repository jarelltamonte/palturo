import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/profile_service.dart';

void main() {
  test('requires every profile field and a role skill', () {
    expect(
      isProfileComplete(
        avatarUrl: 'https://example.test/avatar.jpg',
        bio: 'Hello',
        languages: const ['English'],
        learningStyles: const ['Visual'],
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
        hasRoleSkills: false,
      ),
      isFalse,
    );
  });
}
