import 'package:palturo/onboarding/onboarding_models.dart';

class ProfileData {
  final String name;
  final String schedule;
  final String? avatarUrl;
  final List<String> languages;
  final List<String> interests;
  final OnboardingRole? role;
  final List<String> learningSkillIds;
  final List<String> teachingSkillIds;

  const ProfileData({
    required this.name,
    required this.schedule,
    this.avatarUrl,
    this.languages = const [],
    this.interests = const [],
    this.role,
    this.learningSkillIds = const [],
    this.teachingSkillIds = const [],
  });

  ProfileData copyWith({
    String? name,
    String? schedule,
    String? avatarUrl,
    List<String>? languages,
    List<String>? interests,
    OnboardingRole? role,
    List<String>? learningSkillIds,
    List<String>? teachingSkillIds,
  }) {
    return ProfileData(
      name: name ?? this.name,
      schedule: schedule ?? this.schedule,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      languages: languages ?? this.languages,
      interests: interests ?? this.interests,
      role: role ?? this.role,
      learningSkillIds: learningSkillIds ?? this.learningSkillIds,
      teachingSkillIds: teachingSkillIds ?? this.teachingSkillIds,
    );
  }
}