import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/onboarding_models.dart' show OnboardingRole, OnboardingRoleDb;
import 'package:palturo/screen/profile_data.dart';
import '../screen/card/skills_card.dart' show CustomSkill, kOtherPrefix;
import '../onboarding/onboarding_flow.dart' show resolveCategoriesForSkills;
import '../screen/utils/schedule_format.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Reads picked-image bytes without `File(path)`, which throws
  /// "Unsupported operation: _Namespace" on web.
  static Future<Uint8List?> _readUploadBytes(String path) async {
    if (path.startsWith('http')) return null;
    try {
      if (kIsWeb) {
        return await XFile(path).readAsBytes();
      }
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Blob URLs have no usable extension. Prefer the bytes (authoritative on
  /// both platforms), then the source path, then jpg.
  static String _extensionFromBytes(Uint8List bytes) {
    bool startsWith(List<int> signature) {
      if (bytes.length < signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[i] != signature[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return 'png';
    if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'jpg';
    if (startsWith(const [0x47, 0x49, 0x46, 0x38])) return 'gif';
    if (bytes.length >= 12 &&
        startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return '';
  }

  static String _extensionFor(String path) {
    final name = path.split('?').first;
    final dot = name.lastIndexOf('.');
    final ext = dot == -1 ? '' : name.substring(dot + 1);
    return RegExp(r'^[A-Za-z0-9]{1,5}$').hasMatch(ext)
        ? ext.toLowerCase()
        : 'jpg';
  }

  static String _uploadNamePrefix(String base) =>
      base.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  /// Uploads [path] to profile-media and returns its public URL.
  /// Throws if the picked bytes cannot be read, so the caller can abort the
  /// save instead of persisting a local/blob path.
  Future<String> _uploadToProfileMedia(
    String path,
    String filePrefix,
  ) async {
    final bytes = await _readUploadBytes(path);
    if (bytes == null) {
      throw Exception(
        'Could not read the selected image. Please re-select it and try again.',
      );
    }

    final detected = _extensionFromBytes(bytes);
    final ext = detected.isNotEmpty ? detected : _extensionFor(path);
    final fileName = '$filePrefix.$ext';

    await _supabase.storage
        .from('profile-media')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _supabase.storage.from('profile-media').getPublicUrl(fileName);
  }

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
              .select(
                'id, first_name, last_name, display_name, bio, avatar_url, '
                'photos, role, learning_skills, teaching_skills, '
                'learning_styles, languages, availability, skill_categories, '
                'teaching_skill_images, timezone, is_profile_completed, '
                'has_completed_onboarding, created_at, updated_at',
              )
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
          final prefix =
              '${user.id}/photo_${i}_${DateTime.now().millisecondsSinceEpoch}';
          uploadedPhotoUrls[i] = await _uploadToProfileMedia(path, prefix);
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
          final prefix =
              '${user.id}/proof_${_uploadNamePrefix(targetSkillName)}_${DateTime.now().millisecondsSinceEpoch}';
          uploadedSkillImages[targetSkillName] = await _uploadToProfileMedia(
            localOrRemotePath,
            prefix,
          );
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
