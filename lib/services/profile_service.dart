import 'dart:async';
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
import '../onboarding/skill_options.dart' show onboardingInterestLabel;
import '../screen/utils/schedule_format.dart';
import '../utils/media_url.dart';
import 'match_api.dart';

/// A custom skill the Jev classifier refused to attach to the taxonomy.
class RejectedSkill {
  /// The editor row id, so the form can drop exactly this entry.
  final String skillId;
  final String name;

  /// `learn` or `teach`.
  final String kind;

  const RejectedSkill({
    required this.skillId,
    required this.name,
    required this.kind,
  });
}

/// Raised when the Jev skill classifier rejects one or more custom skills.
/// Nothing has been written when this is thrown, so the caller can drop the
/// rejected entries and let the user retry.
class SkillModerationException implements Exception {
  final String message;
  final List<RejectedSkill> skills;

  const SkillModerationException(this.message, {this.skills = const []});

  factory SkillModerationException.rejected(List<RejectedSkill> skills) {
    final names = skills.map((skill) => '"${skill.name}"').toList();
    final subject =
        names.length == 1
            ? names.first
            : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return SkillModerationException(
      names.length == 1
          ? '$subject isn’t a skill PalTuro can add. Try naming a specific, '
              'teachable skill instead.'
          : '$subject aren’t skills PalTuro can add. Try naming specific, '
              'teachable skills instead.',
      skills: List.unmodifiable(skills),
    );
  }

  @override
  String toString() => message;
}

bool isProfileComplete({
  required String? avatarUrl,
  required String bio,
  required List<String> languages,
  required List<String> learningStyles,
  required bool hasRoleSkills,
  bool hasShowcase = true,
}) {
  return avatarUrl != null &&
      avatarUrl.trim().isNotEmpty &&
      bio.trim().isNotEmpty &&
      languages.isNotEmpty &&
      learningStyles.isNotEmpty &&
      hasRoleSkills &&
      hasShowcase;
}

class NameChangeStatus {
  const NameChangeStatus({
    required this.changesUsed,
    required this.changesRemaining,
    required this.canChange,
    this.nextChangeAt,
  });

  final int changesUsed;
  final int changesRemaining;
  final bool canChange;
  final DateTime? nextChangeAt;

  factory NameChangeStatus.fromMap(Map<String, dynamic> map) {
    return NameChangeStatus(
      changesUsed: (map['changes_used'] as num?)?.toInt() ?? 0,
      changesRemaining: (map['changes_remaining'] as num?)?.toInt() ?? 0,
      canChange: map['can_change'] as bool? ?? false,
      nextChangeAt:
          map['next_change_at'] == null
              ? null
              : DateTime.tryParse(map['next_change_at'].toString()),
    );
  }
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

  /// ISO base media files (mp4, mov, m4v) carry `ftyp` at byte 4; WebM starts
  /// with the EBML header. The brand separates video from HEIC photos, which
  /// share the same box.
  static String _videoExtensionFromBytes(Uint8List bytes) {
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12));
      if (brand == 'qt  ') return 'mov';
      if (const {
        'isom',
        'iso2',
        'iso4',
        'iso5',
        'mp41',
        'mp42',
        'avc1',
        'M4V ',
        'M4VH',
        'M4VP',
        'dash',
      }.contains(brand)) {
        return 'mp4';
      }
      return '';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      return 'webm';
    }
    return '';
  }

  static bool _looksLikeHeic(Uint8List bytes) {
    if (bytes.length < 12 ||
        bytes[4] != 0x66 ||
        bytes[5] != 0x74 ||
        bytes[6] != 0x79 ||
        bytes[7] != 0x70) {
      return false;
    }
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    return const {
      'heic',
      'heix',
      'hevc',
      'heim',
      'mif1',
      'msf1',
    }.contains(brand);
  }

  static String _extensionFor(String path) {
    final name = path.split('?').first;
    final dot = name.lastIndexOf('.');
    final ext = dot == -1 ? '' : name.substring(dot + 1);
    return RegExp(r'^[A-Za-z0-9]{1,5}$').hasMatch(ext) ? ext.toLowerCase() : '';
  }

  static String _uploadNamePrefix(String base) =>
      base.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  static const Set<String> _imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const Set<String> _videoExtensions = {'mp4', 'mov', 'webm', 'm4v'};
  static const int _maxImageBytes = 20 * 1024 * 1024;
  static const int _maxVideoBytes = 50 * 1024 * 1024;

  static String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }

  static bool isShowcaseVideo(String value) {
    final path = value.split('?').first.toLowerCase();
    return _videoExtensions.any((ext) => path.endsWith('.$ext'));
  }

  /// Uploads [path] to [bucket] and returns a public URL or object path.
  Future<String> _uploadToBucket(
    String bucket,
    String path,
    String filePrefix, {
    required bool publicUrl,
    bool allowVideo = false,
  }) async {
    final bytes = await _readUploadBytes(path);
    if (bytes == null) {
      throw Exception(
        'Could not read the selected file. Please re-select it and try again.',
      );
    }

    if (_looksLikeHeic(bytes)) {
      throw Exception(
        'HEIC photos are not supported yet. Choose JPG, PNG, or WebP.',
      );
    }

    final pathExt = _extensionFor(path);
    final videoExt = allowVideo ? _videoExtensionFromBytes(bytes) : '';
    final detected =
        videoExt.isNotEmpty
            ? (_videoExtensions.contains(pathExt) ? pathExt : videoExt)
            : _extensionFromBytes(bytes);
    final ext = detected.isNotEmpty ? detected : pathExt;
    final isVideo = _videoExtensions.contains(ext);

    if (isVideo && !allowVideo) {
      throw Exception(
        'That file is a video. Add videos to a skill showcase instead.',
      );
    }
    if (!isVideo && !_imageExtensions.contains(ext)) {
      throw Exception(
        allowVideo
            ? 'Unsupported file type. Use JPG, PNG, WebP, MP4, MOV, or WebM.'
            : 'Unsupported image type. Use JPG, PNG, or WebP.',
      );
    }

    final limit = isVideo ? _maxVideoBytes : _maxImageBytes;
    if (bytes.length > limit) {
      final mb = isVideo ? 50 : 20;
      throw Exception(
        '${isVideo ? 'Video' : 'Image'} is too large. Please choose one under '
        '$mb MB.',
      );
    }

    final fileName = '$filePrefix.$ext';
    await _supabase.storage
        .from(bucket)
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeFor(ext),
          ),
        );
    return publicUrl
        ? _supabase.storage.from(bucket).getPublicUrl(fileName)
        : fileName;
  }

  Future<String> _uploadToProfileMedia(String path, String filePrefix) =>
      _uploadToBucket('profile-media', path, filePrefix, publicUrl: true);

  /// Showcases are public because they render on discovery cards. The bucket
  /// accepts images and short videos.
  Future<String> _uploadToShowcase(String path, String filePrefix) =>
      _uploadToBucket(
        'skill-showcases',
        path,
        filePrefix,
        publicUrl: true,
        allowVideo: true,
      );

  String _interestLabel(String id) => onboardingInterestLabel(id);

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
        controller.learningInterests.map(_interestLabel).toList();

    final resolvedTeaching =
        controller.teachingInterests.map(_interestLabel).toList();

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
              .select('avatar_url, bio, teaching_skill_images')
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

    final existingShowcase = existingProfile?['teaching_skill_images'];
    final hasExistingShowcase =
        existingShowcase is Map &&
        existingShowcase.values.any(
          (value) => value is String && value.trim().isNotEmpty,
        );

    final isComplete =
        !hasUnresolvedOthers &&
        isProfileComplete(
          avatarUrl: existingProfile?['avatar_url'] as String?,
          bio: (existingProfile?['bio'] ?? '') as String,
          languages: controller.languages.toList(),
          learningStyles: controller.learningStyles.toList(),
          hasRoleSkills: hasRoleSkills,
          hasShowcase:
              !(controller.role == OnboardingRole.teach ||
                  (controller.role == OnboardingRole.both &&
                      resolvedTeaching.isNotEmpty)) ||
              hasExistingShowcase,
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

      // Showcases written by the editor live in public.skill_showcases and are
      // public URLs. Merge them over the legacy map so the editor shows what
      // discovery actually sees.
      final showcaseImages = <String, String>{};
      try {
        final rows = await _supabase
            .from('skill_showcases')
            .select('media_url, caption, skill:skill_nodes(name)')
            .eq('user_id', user.id);
        for (final row in rows as List) {
          if (row is! Map) continue;
          final media = (row['media_url'] ?? '').toString();
          final skill = row['skill'];
          final skillName =
              skill is Map ? (skill['name'] ?? '').toString().trim() : '';
          final caption = (row['caption'] ?? '').toString().trim();
          // Key by the selectable skill so the editor can match it to a row.
          // Captions can stay specific ("Cooking Pinakbet") without breaking
          // the depth-2 selection.
          final key = skillName.isNotEmpty ? skillName : caption;
          if (media.isNotEmpty && key.isNotEmpty) {
            showcaseImages[key] = media;
          }
        }
      } catch (_) {
        // A read failure should not block opening the profile.
      }

      // Private proof objects are stored as paths; sign them for display.
      final proofImages = <String, String>{};
      final sourceImages = <String, String>{
        ...profile.teachingSkillImages,
        ...showcaseImages,
      };
      for (final entry in sourceImages.entries) {
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

  Future<NameChangeStatus?> getNameChangeStatus() async {
    final res = await _supabase.rpc('get_name_change_status') as List;
    if (res.isEmpty) return null;
    return NameChangeStatus.fromMap(
      Map<String, dynamic>.from(res.first as Map),
    );
  }

  Future<NameChangeStatus> changeName(String firstName, String lastName) async {
    final res =
        await _supabase.rpc(
              'change_profile_name',
              params: {
                'p_first_name': firstName.trim(),
                'p_last_name': lastName.trim(),
              },
            )
            as List;
    if (res.isEmpty) {
      throw Exception('The name change did not complete.');
    }
    return NameChangeStatus.fromMap(
      Map<String, dynamic>.from(res.first as Map),
    );
  }

  Future<String?> _classifyCustomSkill(
    String name,
    String kind, {
    String skillId = '',
  }) async {
    try {
      final verdict = await MatchApi.classifySkill(name: name, kind: kind);
      final status = verdict?['status']?.toString();
      final node = verdict?['node'];
      if ((status == 'attached' || status == 'pending') &&
          node is Map &&
          node['name'] is String) {
        return node['name'] as String;
      }
      if (status == 'rejected') {
        throw SkillModerationException.rejected([
          RejectedSkill(skillId: skillId, name: name, kind: kind),
        ]);
      }
      return null;
    } catch (e) {
      if (e is SkillModerationException) rethrow;
      // The classifier may be unavailable; keep the existing custom-skill
      // fallback rather than losing the user's work.
      return null;
    }
  }

  Future<ProfileData> updateProfile(
    ProfileData updatedProfile, {
    List<String?>? newPhotoLocalPaths,
    Map<String, String>? teachingSkillImages,
    void Function(String skillName)? onClassifyingSkill,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final Set<String> allCategorySlugs = {};
    final List<RejectedSkill> rejectedSkills = [];

    final List<String> resolvedLearning = [];
    final List<Map<String, String>> learningPayload = [];
    for (final skill in updatedProfile.learningSkillIds) {
      String? resolved;
      final custom = CustomSkill.tryParse(skill);
      if (custom != null && custom.isValid) {
        try {
          onClassifyingSkill?.call(custom.text);
          resolved =
              await _classifyCustomSkill(
                custom.text,
                'learn',
                skillId: skill,
              ) ??
              _toTitleCase(custom.text);
        } on SkillModerationException catch (e) {
          rejectedSkills.addAll(e.skills);
          continue;
        }
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
        try {
          onClassifyingSkill?.call(custom.text);
          formatted =
              await _classifyCustomSkill(
                custom.text,
                'teach',
                skillId: skill,
              ) ??
              _toTitleCase(custom.text);
        } on SkillModerationException catch (e) {
          rejectedSkills.addAll(e.skills);
          continue;
        }
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

    // Nothing has been uploaded or written yet: fail before any side effect so
    // the editor can drop the rejected rows and let the user retry.
    if (rejectedSkills.isNotEmpty) {
      throw SkillModerationException.rejected(rejectedSkills);
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
                '${user.id}/showcase_${_uploadNamePrefix(targetSkillName)}_${DateTime.now().millisecondsSinceEpoch}';
            uploadedSkillImages[targetSkillName] = await _uploadToShowcase(
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
    final List<String> showcaseToDelete = [];
    for (final oldUrl in oldStorageUrls) {
      // Showcase media is either a bare private path, a signed URL, or a
      // public skill-showcases URL.
      final showcasePath =
          oldUrl.startsWith('http')
              ? (_extractStoragePath(oldUrl, 'skill-proofs') ??
                  _extractStoragePath(oldUrl, 'skill-showcases'))
              : (oldUrl.contains('://') ? null : oldUrl);
      if (showcasePath != null) {
        if (!preservedProofPaths.contains(showcasePath) &&
            !preservedMediaUrls.contains(oldUrl)) {
          showcaseToDelete.add(showcasePath);
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
    if (showcaseToDelete.isNotEmpty) {
      // New media lives in skill-showcases; legacy proofs live in skill-proofs.
      // Removing from the wrong bucket is a no-op, so try both.
      for (final bucket in const ['skill-showcases', 'skill-proofs']) {
        try {
          await _supabase.storage.from(bucket).remove(showcaseToDelete);
        } catch (_) {}
      }
    }

    final availableDays = parseAvailableDays(
      updatedProfile.availableDays.isNotEmpty
          ? updatedProfile.availableDays
          : updatedProfile.schedule,
    );

    final primaryAvatar = MediaUrl.sanitize(
      uploadedPhotoUrls.isNotEmpty ? uploadedPhotoUrls[0] : null,
    );
    final safePhotos =
        uploadedPhotoUrls.map(MediaUrl.sanitize).whereType<String>().toList();
    final safeSkillImages = <String, String>{};
    uploadedSkillImages.forEach((key, value) {
      if (MediaUrl.isAllowedOrPath(value)) {
        safeSkillImages[key] = value;
      }
    });

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
      hasShowcase:
          !(updatedProfile.role == OnboardingRole.teach ||
              (updatedProfile.role == OnboardingRole.both &&
                  resolvedTeaching.isNotEmpty)) ||
          safeSkillImages.isNotEmpty,
    );

    // The RPC owns the skill arrays. Run it first so the arrays and
    // user_skills stay consistent even if the later profile update fails;
    // the UI reports the failure and the save is safe to retry.
    await _saveUserSkills(learningPayload, teachingPayload);

    await _supabase
        .from('profiles')
        .update({
          'bio': updatedProfile.bio,
          'avatar_url': primaryAvatar,
          'photos': safePhotos,
          'teaching_skill_images': safeSkillImages,
          'role': updatedProfile.role?.dbValue ?? 'learner',
          'skill_categories': allCategorySlugs.toList(),
          'learning_styles': updatedProfile.interests,
          'languages': updatedProfile.languages,
          'availability': availableDays,
          'is_profile_completed': isCompleted,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id);

    // Discovery cards read public.skill_showcases, not
    // profiles.teaching_skill_images. Keep the rows in step with the editor so
    // an attached showcase actually appears on the card.
    if (teachingSkillImages != null) {
      final rows = <Map<String, dynamic>>[];
      uploadedSkillImages.forEach((skill, media) {
        if (!media.startsWith('http')) return;
        rows.add({
          'caption': skill,
          'media_url': media,
          'media_kind': isShowcaseVideo(media) ? 'video' : 'image',
        });
      });
      await _supabase.rpc('set_skill_showcases', params: {'p_items': rows});
    }

    final refreshed = await getCurrentUserProfile();

    // Re-vectorization is not part of the save contract: get-matches heals
    // stale embeddings on the next read. Awaiting it here made edits feel
    // stuck for tens of seconds after the profile had already been written.
    unawaited(refreshEmbeddings());

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
