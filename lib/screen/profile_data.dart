import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/screen/utils/schedule_format.dart';

class ProfileData {
  final String id;
  final String firstName;
  final String lastName;
  final String schedule;
  final List<String> availableDays;
  final String? avatarUrl;
  final List<String?> photos;
  final String bio;
  final List<String> languages;
  final List<String> interests;

  /// Teaching styles for mentors (empty for learner-only profiles).
  final List<String> teachingStyles;
  final OnboardingRole? role;
  final List<String> learningSkillIds;
  final List<String> teachingSkillIds;
  final Map<String, String> teachingSkillImages;

  /// Per-placement notes keyed by taxonomy leaf id (DEV-22).
  final Map<String, String> learningNotes;
  final Map<String, String> teachingNotes;

  /// Whether each stored note passed moderation. Keyed by skill name. A note
  /// text that exists but is not approved does not make a side discoverable.
  final Map<String, bool> learningNoteApproved;
  final Map<String, bool> teachingNoteApproved;

  /// Teaching skills backed by an approved taxonomy node. Unresolved custom
  /// skills are excluded because the backend does not treat them as public
  /// placements.
  final Set<String> approvedTeachingSkills;

  /// Queue status for notes that are still pending or were rejected, keyed by
  /// `kind|name`. Approved notes are absent.
  final Map<String, String> noteReviewStatus;

  /// True only when the notes query succeeded. A save must not overwrite
  /// stored notes with empty values after a transient read failure.
  final bool notesLoaded;

  /// Note ids edited in this session (so only those are re-moderated).
  final Set<String> changedLearningNotes;
  final Set<String> changedTeachingNotes;
  final bool hasCompletedOnboarding;
  final bool isProfileCompleted;

  /// Private demographics. Used for aggregate analytics only; never shown on
  /// cards or in a public profile.
  final int? age;
  final String? gender;

  ProfileData({
    this.id = '',
    String? name,
    String? firstName,
    String? lastName,
    required this.schedule,
    this.availableDays = const [],
    this.avatarUrl,
    this.photos = const [null],
    this.bio = '',
    this.languages = const [],
    this.interests = const [],
    this.teachingStyles = const [],
    this.role,
    this.learningSkillIds = const [],
    this.teachingSkillIds = const [],
    this.teachingSkillImages = const {},
    this.learningNotes = const {},
    this.teachingNotes = const {},
    this.learningNoteApproved = const {},
    this.teachingNoteApproved = const {},
    this.approvedTeachingSkills = const {},
    this.noteReviewStatus = const {},
    this.notesLoaded = false,
    this.changedLearningNotes = const {},
    this.changedTeachingNotes = const {},
    this.hasCompletedOnboarding = false,
    this.isProfileCompleted = false,
    this.age,
    this.gender,
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

  bool get hasAnySkill =>
      learningSkillIds.isNotEmpty || teachingSkillIds.isNotEmpty;

  /// The role implied by the current skills, or null when there are none.
  OnboardingRole? get derivedRole => roleForSkills(
    hasLearning: learningSkillIds.isNotEmpty,
    hasTeaching: teachingSkillIds.isNotEmpty,
  );

  /// Role used across the app: skills win once they exist, and the stored
  /// role only matters for a profile that has not picked a skill yet.
  OnboardingRole? get effectiveRole => hasAnySkill ? derivedRole : role;

  /// True when For You should show the setup checklist instead of looking for
  /// matches: no role chosen, or no skill picked on either side.
  bool get needsSetup => role == null || !hasAnySkill;

  /// Teaching skills that do not have showcase media yet.
  List<String> get missingShowcaseSkillIds => teachingSkillIds
      .where((id) => (teachingSkillImages[id]?.trim() ?? '').isEmpty)
      .toList(growable: false);

  /// True when at least one teaching skill has showcase media. This is the
  /// actual discoverability gate used by the backend.
  bool get hasAnyShowcase =>
      teachingSkillIds.any(
        (id) => (teachingSkillImages[id]?.trim() ?? '').isNotEmpty,
      ) ||
      teachingSkillImages.values.any((value) => value.trim().isNotEmpty);

  /// True when the mentor is not discoverable because no showcase exists yet.
  bool get needsShowcase => teachingSkillIds.isNotEmpty && !hasAnyShowcase;

  /// True when at least one teaching skill still lacks its own showcase.
  bool get hasIncompleteShowcases => missingShowcaseSkillIds.isNotEmpty;

  /// True when every teaching skill has a non-empty note.
  bool get hasAllTeachingNotes => teachingSkillIds.every(
    (id) => (teachingNotes[id]?.trim() ?? '').isNotEmpty,
  );

  bool get hasApprovedTeachingSkill => approvedTeachingSkills.isNotEmpty;

  /// True when every approved teaching skill has a present, approved note.
  bool get hasAllApprovedTeachingNotes => approvedTeachingSkills.every(
    (id) =>
        (teachingNotes[id]?.trim() ?? '').isNotEmpty &&
        (teachingNoteApproved[id] ?? false),
  );

  /// True when approved teaching notes exist but at least one is in moderation.
  bool get hasTeachingNotesPendingReview =>
      hasApprovedTeachingSkill &&
      approvedTeachingSkills.every(
        (id) => (teachingNotes[id]?.trim() ?? '').isNotEmpty,
      ) &&
      !hasAllApprovedTeachingNotes;

  /// The mentor side is discoverable only with an approved teaching skill,
  /// showcase media, and an approved note on every approved teaching skill.
  bool get mentorReady =>
      notesLoaded &&
      hasApprovedTeachingSkill &&
      hasAnyShowcase &&
      hasAllApprovedTeachingNotes;

  /// 0..1 progress toward mentor discovery: showcase plus one approved note
  /// for every approved teaching skill.
  double get mentorProgress {
    if (!hasApprovedTeachingSkill) return 0;
    final total = 1 + approvedTeachingSkills.length;
    final completed =
        (hasAnyShowcase ? 1 : 0) +
        approvedTeachingSkills
            .where(
              (name) =>
                  (teachingNotes[name]?.trim() ?? '').isNotEmpty &&
                  (teachingNoteApproved[name] ?? false),
            )
            .length;
    return (completed / total).clamp(0.0, 1.0);
  }

  /// True when the profile teaches but is not yet discoverable as a mentor.
  bool get needsMentorSetup =>
      notesLoaded &&
      !needsSetup &&
      (effectiveRole == OnboardingRole.teach ||
          effectiveRole == OnboardingRole.both) &&
      !mentorReady;

  String? noteReviewStatusFor(String kind, String name) =>
      noteReviewStatus['$kind|$name'];

  bool isNoteRejected(String kind, String name) =>
      noteReviewStatusFor(kind, name) == 'rejected';

  bool isNotePending(String kind, String name) =>
      noteReviewStatusFor(kind, name) == 'pending';

  List<String> get rejectedLearningNoteNames => learningSkillIds
      .where((name) => isNoteRejected('learn', name))
      .toList(growable: false);

  List<String> get rejectedTeachingNoteNames => teachingSkillIds
      .where((name) => isNoteRejected('teach', name))
      .toList(growable: false);

  List<String> get rejectedNoteNames => {
    ...rejectedLearningNoteNames,
    ...rejectedTeachingNoteNames,
  }.toList(growable: false);

  bool get hasRejectedNotes => rejectedNoteNames.isNotEmpty;

  String? get genderLabel => switch (gender) {
    'woman' => 'Woman',
    'man' => 'Man',
    'nonbinary' => 'Non-binary',
    'prefer_not_to_say' => 'Prefer not to say',
    _ => null,
  };

  ProfileData copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? schedule,
    List<String>? availableDays,
    String? avatarUrl,
    List<String?>? photos,
    String? bio,
    List<String>? languages,
    List<String>? interests,
    List<String>? teachingStyles,
    OnboardingRole? role,
    List<String>? learningSkillIds,
    List<String>? teachingSkillIds,
    Map<String, String>? teachingSkillImages,
    Map<String, String>? learningNotes,
    Map<String, String>? teachingNotes,
    Map<String, bool>? learningNoteApproved,
    Map<String, bool>? teachingNoteApproved,
    Set<String>? approvedTeachingSkills,
    Map<String, String>? noteReviewStatus,
    bool? notesLoaded,
    Set<String>? changedLearningNotes,
    Set<String>? changedTeachingNotes,
    bool? hasCompletedOnboarding,
    bool? isProfileCompleted,
    int? age,
    String? gender,
    bool clearAge = false,
    bool clearGender = false,
    bool clearAvatar = false,
  }) {
    return ProfileData(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      schedule: schedule ?? this.schedule,
      availableDays: availableDays ?? this.availableDays,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      photos: photos ?? this.photos,
      bio: bio ?? this.bio,
      languages: languages ?? this.languages,
      interests: interests ?? this.interests,
      teachingStyles: teachingStyles ?? this.teachingStyles,
      role: role ?? this.role,
      learningSkillIds: learningSkillIds ?? this.learningSkillIds,
      teachingSkillIds: teachingSkillIds ?? this.teachingSkillIds,
      teachingSkillImages: teachingSkillImages ?? this.teachingSkillImages,
      learningNotes: learningNotes ?? this.learningNotes,
      teachingNotes: teachingNotes ?? this.teachingNotes,
      learningNoteApproved: learningNoteApproved ?? this.learningNoteApproved,
      teachingNoteApproved: teachingNoteApproved ?? this.teachingNoteApproved,
      approvedTeachingSkills:
          approvedTeachingSkills ?? this.approvedTeachingSkills,
      noteReviewStatus: noteReviewStatus ?? this.noteReviewStatus,
      notesLoaded: notesLoaded ?? this.notesLoaded,
      changedLearningNotes: changedLearningNotes ?? this.changedLearningNotes,
      changedTeachingNotes: changedTeachingNotes ?? this.changedTeachingNotes,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      age: clearAge ? null : (age ?? this.age),
      gender: clearGender ? null : (gender ?? this.gender),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  factory ProfileData.fromMap(
    Map<String, dynamic> map, {
    String fallbackFirst = 'User',
    String fallbackLast = '',
  }) {
    OnboardingRole? parsedRole;
    final roleStr = map['role'] as String?;
    if (roleStr != null) parsedRole = OnboardingRoleDb.fromDb(roleStr);

    final parsedDays = parseAvailableDays(map['availability']);
    final formattedSchedule = formatScheduleDays(parsedDays);

    final rawPhotos = map['photos'] as List<dynamic>?;
    // One profile photo. Older rows may still hold three; keep the main one.
    final parsedPhotos = <String?>[null];
    if (rawPhotos != null && rawPhotos.isNotEmpty) {
      final main = rawPhotos.first;
      if (main != null) parsedPhotos[0] = main.toString();
    }
    if (parsedPhotos[0] == null && map['avatar_url'] != null) {
      parsedPhotos[0] = map['avatar_url'] as String;
    }

    final learningSkills = _stringList(map['learning_skills']);
    final teachingSkills = _stringList(map['teaching_skills']);
    final storedRole = parsedRole;
    final resolvedRole =
        learningSkills.isNotEmpty || teachingSkills.isNotEmpty
            ? roleForSkills(
              hasLearning: learningSkills.isNotEmpty,
              hasTeaching: teachingSkills.isNotEmpty,
            )
            : storedRole;

    final rawSkillImages = map['teaching_skill_images'];
    Map<String, String> parsedSkillImages = {};
    if (rawSkillImages is Map) {
      parsedSkillImages = rawSkillImages.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }

    int? parsedAge;
    final rawAge = map['age'];
    if (rawAge is num) {
      parsedAge = rawAge.toInt();
    } else if (rawAge is String) {
      parsedAge = int.tryParse(rawAge.trim());
    }

    return ProfileData(
      id: map['id'] as String? ?? '',
      firstName:
          (map['first_name'] as String?)?.trim().isNotEmpty == true
              ? map['first_name'] as String
              : fallbackFirst,
      lastName: (map['last_name'] as String?) ?? fallbackLast,
      schedule: formattedSchedule,
      availableDays: parsedDays,
      avatarUrl: map['avatar_url'] as String?,
      photos: parsedPhotos,
      bio: (map['bio'] as String?) ?? '',
      languages: _stringList(map['languages']),
      interests: _stringList(map['learning_styles']),
      teachingStyles: _stringList(map['teaching_styles']),
      role: resolvedRole,
      learningSkillIds: learningSkills,
      teachingSkillIds: teachingSkills,
      teachingSkillImages: parsedSkillImages,
      hasCompletedOnboarding: map['has_completed_onboarding'] as bool? ?? false,
      isProfileCompleted: map['is_profile_completed'] as bool? ?? false,
      age: parsedAge,
      gender:
          (map['gender'] as String?)?.trim().isEmpty == true
              ? null
              : map['gender'] as String?,
    );
  }
}
