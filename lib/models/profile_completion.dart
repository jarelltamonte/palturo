import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/profile_data.dart';

class ProfileCompletionItem {
  const ProfileCompletionItem({
    required this.label,
    required this.detail,
    required this.complete,
    required this.weight,
  });

  final String label;
  final String detail;
  final bool complete;
  final int weight;
}

class ProfileCompletion {
  const ProfileCompletion(this.items);

  final List<ProfileCompletionItem> items;

  int get totalWeight => items.fold(0, (sum, item) => sum + item.weight);

  int get completedWeight => items
      .where((item) => item.complete)
      .fold(0, (sum, item) => sum + item.weight);

  double get fraction => totalWeight == 0 ? 1 : completedWeight / totalWeight;

  int get percent => (fraction * 100).round().clamp(0, 100);

  bool get isComplete => items.every((item) => item.complete);

  int get remainingCount => items.where((item) => !item.complete).length;

  List<ProfileCompletionItem> get missing =>
      items.where((item) => !item.complete).toList(growable: false);
}

ProfileCompletion computeProfileCompletion(ProfileData profile) {
  final effectiveRole = profile.effectiveRole;
  final wantsTeaching =
      effectiveRole == OnboardingRole.teach ||
      effectiveRole == OnboardingRole.both;

  final hasPhoto =
      profile.avatarUrl?.trim().isNotEmpty == true ||
      profile.photos.any((photo) => photo?.trim().isNotEmpty == true);

  final missingNotes = <String>[
    ...profile.learningSkillIds.where(
      (id) => (profile.learningNotes[id]?.trim() ?? '').isEmpty,
    ),
    ...profile.teachingSkillIds.where(
      (id) => (profile.teachingNotes[id]?.trim() ?? '').isEmpty,
    ),
  ];

  final items = <ProfileCompletionItem>[
    ProfileCompletionItem(
      label: 'Profile photo',
      detail: 'Add a clear photo so people know who they are meeting.',
      complete: hasPhoto,
      weight: 2,
    ),
    ProfileCompletionItem(
      label: 'Bio',
      detail: 'Write a short intro about you and what you want to exchange.',
      complete: profile.bio.trim().isNotEmpty,
      weight: 1,
    ),
    ProfileCompletionItem(
      label: 'Role and skills',
      detail:
          'Add a learning or teaching skill. Your role follows automatically.',
      complete: profile.hasAnySkill,
      weight: 3,
    ),
    ProfileCompletionItem(
      label: 'Skill notes',
      detail: 'Add a note to each skill. It appears on your card.',
      complete: profile.hasAnySkill && missingNotes.isEmpty,
      weight: 2,
    ),
    ProfileCompletionItem(
      label: 'Languages',
      detail: 'Add the languages you can use with a Pal.',
      complete: profile.languages.isNotEmpty,
      weight: 1,
    ),
    ProfileCompletionItem(
      label: 'Availability',
      detail: 'Set the days you are usually free.',
      complete: profile.availableDays.isNotEmpty,
      weight: 1,
    ),
    ProfileCompletionItem(
      label: 'Learning style',
      detail: 'Pick how you like to learn.',
      complete: profile.interests.isNotEmpty,
      weight: 1,
    ),
    if (wantsTeaching)
      ProfileCompletionItem(
        label: 'Teaching style',
        detail: 'Pick how you like to teach.',
        complete: profile.teachingStyles.isNotEmpty,
        weight: 1,
      ),
    if (wantsTeaching)
      ProfileCompletionItem(
        label: 'Showcase',
        detail: 'Add a photo or short video to a teaching skill.',
        complete: profile.hasAnyShowcase,
        weight: 2,
      ),
    ProfileCompletionItem(
      label: 'Age',
      detail: 'Private. Helps us understand the community.',
      complete: profile.age != null,
      weight: 1,
    ),
    ProfileCompletionItem(
      label: 'Gender',
      detail: 'Private. Helps us understand the community.',
      complete: profile.gender != null,
      weight: 1,
    ),
  ];

  return ProfileCompletion(items);
}
