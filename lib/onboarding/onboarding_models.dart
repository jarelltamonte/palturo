enum OnboardingRole { learn, teach, both }

/// One mandatory note page per learner skill. These bounds are shared by the
/// note screen and the completion gate so they cannot drift apart.
const int kOnboardingNoteMinLength = 10;
const int kOnboardingNoteMaxLength = 150;

/// Role follows the skills a profile actually has.
///
/// The role picker only seeds setup. Afterwards a teaching skill means mentor,
/// a learning skill means learner, both means both, and removing the last skill
/// of a kind removes that role. A profile with no skills has no derived role.
OnboardingRole? roleForSkills({
  required bool hasLearning,
  required bool hasTeaching,
}) {
  if (hasLearning && hasTeaching) return OnboardingRole.both;
  if (hasTeaching) return OnboardingRole.teach;
  if (hasLearning) return OnboardingRole.learn;
  return null;
}

extension OnboardingRoleLabel on OnboardingRole {
  String get displayLabel => switch (this) {
    OnboardingRole.learn => 'Learner',
    OnboardingRole.teach => 'Mentor',
    OnboardingRole.both => 'Learner and Mentor',
  };
}

/// DB <-> UI mapping: the profiles.role column enum is (learner, mentor, both)
/// while the UI enum historically uses learn/teach. Keep one conversion point.
extension OnboardingRoleDb on OnboardingRole {
  /// Value written to the `profiles.role` column.
  String get dbValue => switch (this) {
    OnboardingRole.learn => 'learner',
    OnboardingRole.teach => 'mentor',
    OnboardingRole.both => 'both',
  };

  /// Parse a DB role value (also accepts legacy 'learn'/'teach' strings).
  static OnboardingRole? fromDb(String? value) => switch (value) {
    'learner' || 'learn' => OnboardingRole.learn,
    'mentor' || 'teach' => OnboardingRole.teach,
    'both' => OnboardingRole.both,
    _ => null,
  };
}

class OnboardingOption {
  final String id;
  final String label;
  const OnboardingOption(this.id, this.label);
}

/// Result of adding a custom skill during onboarding.
///
/// Moderation runs as soon as the chip is created, so the interests step can
/// show the checked name (or a friendly reason) without waiting for save.
class OnboardingCreateResult {
  final String? label;
  final String? message;

  const OnboardingCreateResult.added(String this.label) : message = null;
  const OnboardingCreateResult.failed(String this.message) : label = null;
}

class RoleOption {
  final OnboardingRole role;
  final String iconAsset;
  final String label;
  const RoleOption(this.role, this.iconAsset, this.label);
}
