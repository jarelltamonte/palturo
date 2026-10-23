enum OnboardingRole { learn, teach, both }


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
class RoleOption {
  final OnboardingRole role;
  final String iconAsset;
  final String label;
  const RoleOption(this.role, this.iconAsset, this.label);
}