import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/onboarding_models.dart'
    show OnboardingRole, OnboardingRoleDb;
import 'package:palturo/screen/profile_data.dart';
import '../screen/card/skills_card.dart' show CustomSkill, kOtherPrefix;
import '../onboarding/onboarding_flow.dart' show resolveCategoriesForSkills;
import '../screen/utils/schedule_format.dart';

bool isProfileComplete({
  required String? avatarUrl,
  required String bio,
  required List<String> languages,
  required List<String> learningStyles,
  required bool hasRoleSkills,
}) {
  return avatarUrl != null &&
      avatarUrl.trim().isNotEmpty &&
      bio.trim().isNotEmpty &&
      languages.isNotEmpty &&
      learningStyles.isNotEmpty &&
      hasRoleSkills;
}

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
    return RegExp(r'^[A-Za-z0-9]{1,5}$').hasMatch(ext) ? ext.toLowerCase() : '';
  }

  static String _uploadNamePrefix(String base) =>
      base.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  /// Uploads [path] to [bucket] and returns a public URL or object path.
  Future<String> _uploadToBucket(
    String bucket,
    String path,
    String filePrefix, {
    required bool publicUrl,
  }) async {
    final bytes = await _readUploadBytes(path);
    if (bytes == null) {
      throw Exception(
        'Could not read the selected image. Please re-select it and try again.',
      );
    }
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('Image is too large. Please choose one under 5 MB.');
    }

    final detected = _extensionFromBytes(bytes);
    final ext = detected.isNotEmpty ? detected : _extensionFor(path);
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext.toLowerCase())) {
      throw Exception('Unsupported image type. Use JPG, PNG, or WebP.');
    }
    final fileName = '$filePrefix.$ext';

    await _supabase.storage
        .from(bucket)
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return publicUrl
        ? _supabase.storage.from(bucket).getPublicUrl(fileName)
        : fileName;
  }

  Future<String> _uploadToProfileMedia(String path, String filePrefix) =>
      _uploadToBucket('profile-media', path, filePrefix, publicUrl: true);

  Future<String> _uploadToSkillProofs(String path, String filePrefix) =>
      _uploadToBucket('skill-proofs', path, filePrefix, publicUrl: false);

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

    Map<String, dynamic>? existingProfile;
    try {
      existingProfile =
          await _supabase
              .from('profiles')
              .select('avatar_url, bio')
              .eq('id', user.id)
              .maybeSingle();
    } catch (_) {
      // Completion is best-effort; a read failure must not block onboarding.
    }

    final hasRoleSkills = switch (controller.role) {
      OnboardingRole.teach => resolvedTeaching.isNotEmpty,
      OnboardingRole.both =>
        resolvedLearning.isNotEmpty || resolvedTeaching.isNotEmpty,
      _ => resolvedLearning.isNotEmpty,
    };

    final isComplete =
        !hasUnresolvedOthers &&
        isProfileComplete(
          avatarUrl: existingProfile?['avatar_url'] as String?,
          bio: (existingProfile?['bio'] ?? '') as String,
          languages: controller.languages.toList(),
          learningStyles: controller.learningStyles.toList(),
          hasRoleSkills: hasRoleSkills,
        );

    await _saveUserSkills(
      resolvedLearning.map((name) => {'name': name}).toList(),
      resolvedTeaching.map((name) => {'name': name}).toList(),
    );

    try {
      await _supabase
          .from('profiles')
          .update({
            'role': controller.role?.dbValue ?? 'learner',
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

      final profile = ProfileData.fromMap(
        response,
        fallbackFirst: metaFirst,
        fallbackLast: metaLast,
      );

      // Private proof objects are stored as paths; sign them for display.
      final proofImages = <String, String>{};
      for (final entry in profile.teachingSkillImages.entries) {
        final value = entry.value;
        if (value.startsWith('http')) {
          proofImages[entry.key] = value;
          continue;
        }
        try {
          final signed = await _supabase.storage
              .from('skill-proofs')
              .createSignedUrl(value, 3600);
          proofImages[entry.key] = signed;
        } catch (_) {
          // Keep the path so a later save does not treat an unreadable proof
          // as removed; the UI may show a broken preview until it can sign.
          proofImages[entry.key] = value;
        }
      }
      final profileWithProofs = profile.copyWith(
        teachingSkillImages: proofImages,
      );

      final learningNotes = <String, String>{};
      final teachingNotes = <String, String>{};
      var notesLoaded = false;
      try {
        final rows = await _supabase
            .from('user_skills')
            .select('kind, note, skill:skill_id(name)')
            .eq('user_id', user.id);
        for (final row in rows as List) {
          final skill = row['skill'];
          final name = skill is Map ? skill['name'] as String? : null;
          final note = (row['note'] as String?)?.trim() ?? '';
          if (name == null || name.isEmpty || note.isEmpty) continue;
          if (row['kind'] == 'learn') {
            learningNotes[name] = note;
          } else if (row['kind'] == 'teach') {
            teachingNotes[name] = note;
          }
        }

        // Notes for custom skills that are not taxonomy nodes yet.
        final privateRows = await _supabase
            .from('user_skill_notes')
            .select('kind, name, note')
            .eq('user_id', user.id);
        for (final row in privateRows as List) {
          final name = (row['name'] as String?)?.trim() ?? '';
          final note = (row['note'] as String?)?.trim() ?? '';
          if (name.isEmpty || note.isEmpty) continue;
          if (row['kind'] == 'learn') {
            learningNotes.putIfAbsent(name, () => note);
          } else if (row['kind'] == 'teach') {
            teachingNotes.putIfAbsent(name, () => note);
          }
        }
        notesLoaded = true;
      } catch (_) {
        // Notes are optional; the profile still loads without them.
      }

      return profileWithProofs.copyWith(
        learningNotes: learningNotes,
        teachingNotes: teachingNotes,
        notesLoaded: notesLoaded,
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
    final List<Map<String, String>> learningPayload = [];
    for (final skill in updatedProfile.learningSkillIds) {
      String? resolved;
      final custom = CustomSkill.tryParse(skill);
      if (custom != null && custom.isValid) {
        resolved = _toTitleCase(custom.text);
        if (custom.categoryId.isNotEmpty) {
          allCategorySlugs.add(custom.categoryId);
        }
      } else if (!skill.startsWith(kOtherPrefix) &&
          skill.toLowerCase() != 'other' &&
          skill.toLowerCase() != 'others') {
        resolved = _toTitleCase(skill);
      }
      if (resolved != null && resolved.isNotEmpty) {
        final note = updatedProfile.learningNotes[skill] ?? '';
        final changed =
            updatedProfile.changedLearningNotes.contains(skill) ||
            (!updatedProfile.notesLoaded && note.trim().isNotEmpty);
        resolvedLearning.add(resolved);
        learningPayload.add({
          'name': resolved,
          if (changed) 'note': note,
          if (changed) '_changed': '1',
        });
      }
    }

    final List<String> resolvedTeaching = [];
    final List<Map<String, String>> teachingPayload = [];
    final Map<String, String> skillIdToResolvedName = {};

    for (final skill in updatedProfile.teachingSkillIds) {
      String? formatted;
      final custom = CustomSkill.tryParse(skill);
      if (custom != null && custom.isValid) {
        formatted = _toTitleCase(custom.text);
        skillIdToResolvedName[skill] = formatted;
        skillIdToResolvedName[custom.text] = formatted;
        if (custom.categoryId.isNotEmpty) {
          allCategorySlugs.add(custom.categoryId);
        }
      } else if (!skill.startsWith(kOtherPrefix) &&
          skill.toLowerCase() != 'other' &&
          skill.toLowerCase() != 'others') {
        formatted = _toTitleCase(skill);
        skillIdToResolvedName[skill] = formatted;
      }
      if (formatted != null && formatted.isNotEmpty) {
        final note = updatedProfile.teachingNotes[skill] ?? '';
        final changed =
            updatedProfile.changedTeachingNotes.contains(skill) ||
            (!updatedProfile.notesLoaded && note.trim().isNotEmpty);
        resolvedTeaching.add(formatted);
        teachingPayload.add({
          'name': formatted,
          if (changed) 'note': note,
          if (changed) '_changed': '1',
        });
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
    final Set<String> existingProofPaths = {};
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
          if (val is String && val.isNotEmpty) {
            oldStorageUrls.add(val);
            if (!val.startsWith('http')) existingProofPaths.add(val);
          }
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
          if (existingProofPaths.contains(localOrRemotePath)) {
            // Existing private path that could not be signed for display;
            // preserve it rather than re-uploading or deleting it.
            uploadedSkillImages[targetSkillName] = localOrRemotePath;
          } else {
            final prefix =
                '${user.id}/proof_${_uploadNamePrefix(targetSkillName)}_${DateTime.now().millisecondsSinceEpoch}';
            uploadedSkillImages[targetSkillName] = await _uploadToSkillProofs(
              localOrRemotePath,
              prefix,
            );
          }
        } else {
          // A signed URL from the private bucket: persist the object path, not
          // the expiring URL. Legacy public profile-media URLs stay as-is.
          final proofPath = _extractStoragePath(
            localOrRemotePath,
            'skill-proofs',
          );
          uploadedSkillImages[targetSkillName] = proofPath ?? localOrRemotePath;
        }
      }
    }

    final Set<String> preservedProofPaths =
        uploadedSkillImages.values
            .where((value) => !value.startsWith('http'))
            .toSet();
    final Set<String> preservedMediaUrls = {
      ...uploadedPhotoUrls.whereType<String>(),
      ...uploadedSkillImages.values.where((value) => value.startsWith('http')),
    };

    final List<String> mediaToDelete = [];
    final List<String> proofToDelete = [];
    for (final oldUrl in oldStorageUrls) {
      // Private proof paths are stored as bare paths or signed URLs.
      final proofPath =
          oldUrl.startsWith('http')
              ? _extractStoragePath(oldUrl, 'skill-proofs')
              : (oldUrl.contains('://') ? null : oldUrl);
      if (proofPath != null) {
        if (!preservedProofPaths.contains(proofPath)) {
          proofToDelete.add(proofPath);
        }
        continue;
      }

      if (!preservedMediaUrls.contains(oldUrl)) {
        final relativePath = _extractStoragePath(oldUrl, 'profile-media');
        if (relativePath != null && relativePath.startsWith('${user.id}/')) {
          mediaToDelete.add(relativePath);
        }
      }
    }

    if (mediaToDelete.isNotEmpty) {
      try {
        await _supabase.storage.from('profile-media').remove(mediaToDelete);
      } catch (_) {}
    }
    if (proofToDelete.isNotEmpty) {
      try {
        await _supabase.storage.from('skill-proofs').remove(proofToDelete);
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

    final isCompleted = isProfileComplete(
      avatarUrl: primaryAvatar,
      bio: updatedProfile.bio,
      languages: updatedProfile.languages,
      learningStyles: updatedProfile.interests,
      hasRoleSkills: hasSkillsForRole,
    );

    // The RPC owns the skill arrays. Run it first so the arrays and
    // user_skills stay consistent even if the later profile update fails;
    // the UI reports the failure and the save is safe to retry.
    await _saveUserSkills(learningPayload, teachingPayload);

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

  Future<void> _saveUserSkills(
    List<Map<String, String>> learning,
    List<Map<String, String>> teaching,
  ) async {
    try {
      await _supabase.rpc(
        'save_user_skills',
        params: {'p_learning': learning, 'p_teaching': teaching},
      );
    } catch (e) {
      throw Exception('Failed to save skills: $e');
    }
  }
}
