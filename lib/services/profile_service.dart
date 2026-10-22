import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/onboarding_models.dart' show OnboardingRole, OnboardingRoleDb;
import 'package:palturo/screen/profile_data.dart';
import '../screen/card/skills_card.dart' show CustomSkill, kOtherPrefix;
import '../onboarding/onboarding_flow.dart' show resolveCategoriesForSkills;
import '../screen/utils/schedule_format.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _toTitleCase(String text) {
    final clean = text.replaceAll('_', ' ').trim();
    if (clean.isEmpty) return '';
    return clean
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  Future<List<String>> getRandomDistinctSkills({
    required List<String> excludeSkills,
    int limit = 4,
  }) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('learning_skills, teaching_skills')
          .limit(60);

      final Map<String, String> normalizedMap = {};
      final excludeSet =
          excludeSkills
              .map((s) => _toTitleCase(s).toLowerCase().trim())
              .toSet();

      for (final row in response) {
        final learning = (row['learning_skills'] as List<dynamic>?) ?? [];
        final teaching = (row['teaching_skills'] as List<dynamic>?) ?? [];

        for (final skill in [...learning, ...teaching]) {
          if (skill is String) {
            final formatted = _toTitleCase(skill);
            final key = formatted.toLowerCase();

            if (formatted.isNotEmpty && !excludeSet.contains(key)) {
              normalizedMap.putIfAbsent(key, () => formatted);
            }
          }
        }
      }

      final distinctList = normalizedMap.values.toList()..shuffle(Random());
      return distinctList.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fire-and-forget re-vectorization: recomputes this user's passage
  /// embeddings in profile_embeddings (FR-4/FR-6).
  Future<void> refreshEmbeddings() async {
    try {
      await _supabase.functions.invoke('generate-embeddings', body: {});
    } catch (_) {
      // Non-fatal: get-matches self-heals stale embeddings on next read.
    }
  }

  Future<void> saveOnboardingPreferences(
    OnboardingController controller,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated. Cannot save preferences.');
    }

    final availableDays = parseAvailableDays(
      controller.availabilityDays.isNotEmpty
          ? controller.availabilityDays
          : controller.availability.keys,
    );

    final resolvedLearning =
        controller.learningInterests.map((id) {
          if (id.toLowerCase() == 'others') return 'Others';
          return _toTitleCase(id);
        }).toList();

    final resolvedTeaching =
        controller.teachingInterests.map((id) {
          if (id.toLowerCase() == 'others') return 'Others';
          return _toTitleCase(id);
        }).toList();

    final calculatedCategories = resolveCategoriesForSkills([
      ...controller.learningInterests,
      ...controller.teachingInterests,
    ]);

    final hasUnresolvedOthers = [
      ...resolvedLearning,
      ...resolvedTeaching,
    ].any((s) => s.toLowerCase() == 'others');

    final isComplete = !hasUnresolvedOthers;

    try {
      await _supabase
          .from('profiles')
          .update({
            'role': controller.role?.dbValue ?? 'learner',
            'learning_skills': resolvedLearning,
            'teaching_skills': resolvedTeaching,
            'learning_styles': controller.learningStyles.toList(),
            'languages': controller.languages.toList(),
            'availability': availableDays,
            'skill_categories': calculatedCategories,
            'has_completed_onboarding': true,
            'is_profile_completed': isComplete,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (e) {
      throw Exception('Failed to save profile preferences: $e');
    }
    await refreshEmbeddings();
  }

  Future<ProfileData?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response =
          await _supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

      if (response == null) return null;

      final metaFirst =
          user.userMetadata?['first_name'] ??
          user.email?.split('@').first ??
          'User';
      final metaLast = user.userMetadata?['last_name'] ?? '';

      return ProfileData.fromMap(
        response,
        fallbackFirst: metaFirst,
        fallbackLast: metaLast,
      );
    } catch (e) {
      return null;
    }
  }

  String? _extractStoragePath(String url, String bucketName) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final bucketIdx = segments.indexOf(bucketName);
      if (bucketIdx != -1 && bucketIdx < segments.length - 1) {
        return segments.sublist(bucketIdx + 1).join('/');
      }
    } catch (_) {}
    return null;
  }

  Future<ProfileData> updateProfile(
    ProfileData updatedProfile, {
    List<String?>? newPhotoLocalPaths,
    Map<String, String>? teachingSkillImages,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final Set<String> allCategorySlugs = {};

    final List<String> resolvedLearning = [];
    for (final skill in updatedProfile.learningSkillIds) {
      final custom = CustomSkill.tryParse(skill);
      if (custom != null && custom.isValid) {
        resolvedLearning.add(_toTitleCase(custom.text));
        if (custom.categoryId.isNotEmpty) {
          allCategorySlugs.add(custom.categoryId);
        }
      } else if (!skill.startsWith(kOtherPrefix) &&
          skill.toLowerCase() != 'other' &&
          skill.toLowerCase() != 'others') {
        resolvedLearning.add(_toTitleCase(skill));
      }
    }

    final List<String> resolvedTeaching = [];
    final Map<String, String> skillIdToResolvedName = {};

    for (final skill in updatedProfile.teachingSkillIds) {
      final custom = CustomSkill.tryParse(skill);
      if (custom != null && custom.isValid) {
        final formatted = _toTitleCase(custom.text);
        resolvedTeaching.add(formatted);
        skillIdToResolvedName[skill] = formatted;
        skillIdToResolvedName[custom.text] = formatted;
        if (custom.categoryId.isNotEmpty) {
          allCategorySlugs.add(custom.categoryId);
        }
      } else if (!skill.startsWith(kOtherPrefix) &&
          skill.toLowerCase() != 'other' &&
          skill.toLowerCase() != 'others') {
        final formatted = _toTitleCase(skill);
        resolvedTeaching.add(formatted);
        skillIdToResolvedName[skill] = formatted;
      }
    }

    final predefinedCategories = resolveCategoriesForSkills([
      ...resolvedLearning,
      ...resolvedTeaching,
    ]);
    allCategorySlugs.addAll(predefinedCategories);

    final existingRow =
        await _supabase
            .from('profiles')
            .select('photos, avatar_url, teaching_skill_images')
            .eq('id', user.id)
            .maybeSingle();

    final Set<String> oldStorageUrls = {};
    if (existingRow != null) {
      if (existingRow['avatar_url'] is String &&
          (existingRow['avatar_url'] as String).isNotEmpty) {
        oldStorageUrls.add(existingRow['avatar_url'] as String);
      }
      if (existingRow['photos'] is List) {
        for (final p in existingRow['photos'] as List) {
          if (p is String && p.isNotEmpty) oldStorageUrls.add(p);
        }
      }
      if (existingRow['teaching_skill_images'] is Map) {
        for (final val
            in (existingRow['teaching_skill_images'] as Map).values) {
          if (val is String && val.isNotEmpty) oldStorageUrls.add(val);
        }
      }
    }

    List<String?> uploadedPhotoUrls = List.from(updatedProfile.photos);
    if (newPhotoLocalPaths != null) {
      for (int i = 0; i < newPhotoLocalPaths.length; i++) {
        final path = newPhotoLocalPaths[i];
        if (path != null && !path.startsWith('http')) {
          final file = File(path);
          if (await file.exists()) {
            final ext = path.split('.').last;
            final fileName =
                '${user.id}/photo_${i}_${DateTime.now().millisecondsSinceEpoch}.$ext';
            await _supabase.storage
                .from('profile-media')
                .upload(
                  fileName,
                  file,
                  fileOptions: const FileOptions(upsert: true),
                );
            final publicUrl = _supabase.storage
                .from('profile-media')
                .getPublicUrl(fileName);
            uploadedPhotoUrls[i] = publicUrl;
          }
        } else {
          uploadedPhotoUrls[i] = path;
        }
      }
    }

    final Map<String, String> uploadedSkillImages = {};
    if (teachingSkillImages != null) {
      for (final entry in teachingSkillImages.entries) {
        final rawKey = entry.key;
        final localOrRemotePath = entry.value;

        if (localOrRemotePath.isEmpty) continue;

        String? targetSkillName = skillIdToResolvedName[rawKey];
        if (targetSkillName == null) {
          final titleKey = _toTitleCase(rawKey);
          if (resolvedTeaching.contains(titleKey)) {
            targetSkillName = titleKey;
          }
        }

        if (targetSkillName == null ||
            !resolvedTeaching.contains(targetSkillName)) {
          continue;
        }

        if (!localOrRemotePath.startsWith('http')) {
          final file = File(localOrRemotePath);
          if (await file.exists()) {
            final ext = localOrRemotePath.split('.').last;
            final fileName =
                '${user.id}/proof_${targetSkillName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.$ext';

            await _supabase.storage
                .from('profile-media')
                .upload(
                  fileName,
                  file,
                  fileOptions: const FileOptions(upsert: true),
                );

            final publicUrl = _supabase.storage
                .from('profile-media')
                .getPublicUrl(fileName);
            uploadedSkillImages[targetSkillName] = publicUrl;
          }
        } else {
          uploadedSkillImages[targetSkillName] = localOrRemotePath;
        }
      }
    }

    final Set<String> preservedUrls = {
      ...uploadedPhotoUrls.whereType<String>(),
      ...uploadedSkillImages.values,
    };

    final List<String> filesToDelete = [];
    for (final oldUrl in oldStorageUrls) {
      if (!preservedUrls.contains(oldUrl)) {
        final relativePath = _extractStoragePath(oldUrl, 'profile-media');
        if (relativePath != null && relativePath.startsWith('${user.id}/')) {
          filesToDelete.add(relativePath);
        }
      }
    }

    if (filesToDelete.isNotEmpty) {
      try {
        await _supabase.storage.from('profile-media').remove(filesToDelete);
      } catch (_) {}
    }

    final availableDays = parseAvailableDays(
      updatedProfile.availableDays.isNotEmpty
          ? updatedProfile.availableDays
          : updatedProfile.schedule,
    );

    final primaryAvatar =
        uploadedPhotoUrls.isNotEmpty ? uploadedPhotoUrls[0] : null;

    final bool hasSkillsForRole;
    if (updatedProfile.role == OnboardingRole.teach) {
      hasSkillsForRole = resolvedTeaching.isNotEmpty;
    } else if (updatedProfile.role == OnboardingRole.both) {
      hasSkillsForRole =
          resolvedLearning.isNotEmpty || resolvedTeaching.isNotEmpty;
    } else {
      hasSkillsForRole = resolvedLearning.isNotEmpty;
    }

    final isCompleted =
        primaryAvatar != null &&
        primaryAvatar.isNotEmpty &&
        hasSkillsForRole;

    await _supabase
        .from('profiles')
        .update({
          'first_name': updatedProfile.firstName,
          'last_name': updatedProfile.lastName,
          'bio': updatedProfile.bio,
          'avatar_url': primaryAvatar,
          'photos': uploadedPhotoUrls.whereType<String>().toList(),
          'teaching_skill_images': uploadedSkillImages,
          'role': updatedProfile.role?.dbValue ?? 'learner',
          'learning_skills': resolvedLearning,
          'teaching_skills': resolvedTeaching,
          'skill_categories': allCategorySlugs.toList(),
          'learning_styles': updatedProfile.interests,
          'languages': updatedProfile.languages,
          'availability': availableDays,
          'is_profile_completed': isCompleted,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id);

    final refreshed = await getCurrentUserProfile();

    await refreshEmbeddings();

    return refreshed ?? updatedProfile;
  }
}
