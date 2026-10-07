import 'package:palturo/onboarding/onboarding_models.dart';

class ProfileData {
  final String id;
  final String firstName;
  final String lastName;
  final String schedule;
  final String? avatarUrl;
  final List<String?> photos;
  final String bio;
  final List<String> languages;
  final List<String> interests;
  final OnboardingRole? role;
  final List<String> learningSkillIds;
  final List<String> teachingSkillIds;
  final List<String> skillCategories;
  final Map<String, String> teachingSkillImages;
  final bool hasCompletedOnboarding;
  final bool isProfileCompleted;

  ProfileData({
    this.id = '',
    String? name,
    String? firstName,
    String? lastName,
    required this.schedule,
    this.avatarUrl,
    this.photos = const [null, null, null],
    this.bio = '',
    this.languages = const [],
    this.interests = const [],
    this.role,
    this.learningSkillIds = const [],
    this.teachingSkillIds = const [],
    this.skillCategories = const [],
    this.teachingSkillImages = const {},
    this.hasCompletedOnboarding = false,
    this.isProfileCompleted = false,
  }) : firstName = firstName ?? (name != null ? name.split(' ').first : 'User'),
       lastName =
           lastName ??
           (name != null && name.split(' ').length > 1
               ? name.split(' ').sublist(1).join(' ')
               : '');

  String get name {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : 'User';
  }

  ProfileData copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? schedule,
    String? avatarUrl,
    List<String?>? photos,
    String? bio,
    List<String>? languages,
    List<String>? interests,
    OnboardingRole? role,
    List<String>? learningSkillIds,
    List<String>? teachingSkillIds,
    List<String>? skillCategories,
    Map<String, String>? teachingSkillImages,
    bool? hasCompletedOnboarding,
    bool? isProfileCompleted,
  }) {
    return ProfileData(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      schedule: schedule ?? this.schedule,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      photos: photos ?? this.photos,
      bio: bio ?? this.bio,
      languages: languages ?? this.languages,
      interests: interests ?? this.interests,
      role: role ?? this.role,
      learningSkillIds: learningSkillIds ?? this.learningSkillIds,
      teachingSkillIds: teachingSkillIds ?? this.teachingSkillIds,
      skillCategories: skillCategories ?? this.skillCategories,
      teachingSkillImages: teachingSkillImages ?? this.teachingSkillImages,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
    );
  }

  factory ProfileData.fromMap(
    Map<String, dynamic> map, {
    String fallbackFirst = 'User',
    String fallbackLast = '',
  }) {
    OnboardingRole? parsedRole;
    final roleStr = map['role'] as String?;
    if (roleStr != null) parsedRole = OnboardingRoleDb.fromDb(roleStr);

    String formattedSchedule = '';
    if (map['availability'] is Map && (map['availability'] as Map).isNotEmpty) {
      final avail = map['availability'] as Map;
      formattedSchedule = avail.entries
          .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
          .map((e) => '${e.key}: ${e.value}')
          .join('/');
    }

    final rawPhotos = map['photos'] as List<dynamic>?;
    List<String?> parsedPhotos = [null, null, null];
    if (rawPhotos != null && rawPhotos.isNotEmpty) {
      for (int i = 0; i < 3; i++) {
        if (i < rawPhotos.length && rawPhotos[i] != null) {
          parsedPhotos[i] = rawPhotos[i].toString();
        }
      }
    } else if (map['avatar_url'] != null) {
      parsedPhotos[0] = map['avatar_url'] as String;
    }

    final rawSkillImages = map['teaching_skill_images'];
    Map<String, String> parsedSkillImages = {};
    if (rawSkillImages is Map) {
      parsedSkillImages = rawSkillImages.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }

    return ProfileData(
      id: map['id'] as String? ?? '',
      firstName:
          (map['first_name'] as String?)?.trim().isNotEmpty == true
              ? map['first_name'] as String
              : fallbackFirst,
      lastName: (map['last_name'] as String?) ?? fallbackLast,
      schedule: formattedSchedule,
      avatarUrl: map['avatar_url'] as String?,
      photos: parsedPhotos,
      bio: (map['bio'] as String?) ?? '',
      languages: List<String>.from(map['languages'] ?? []),
      interests: List<String>.from(map['learning_styles'] ?? []),
      role: parsedRole,
      learningSkillIds: List<String>.from(map['learning_skills'] ?? []),
      teachingSkillIds: List<String>.from(map['teaching_skills'] ?? []),
      skillCategories: List<String>.from(map['skill_categories'] ?? []),
      teachingSkillImages: parsedSkillImages,
      hasCompletedOnboarding: map['has_completed_onboarding'] as bool? ?? false,
      isProfileCompleted: map['is_profile_completed'] as bool? ?? false,
    );
  }
}
