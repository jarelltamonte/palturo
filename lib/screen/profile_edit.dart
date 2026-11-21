import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/models/profile_completion.dart';
import 'package:palturo/screen/card/skills_card.dart';
import 'package:palturo/onboarding/screens/onboarding_final_screen.dart'
    show
        kLearningStyleOptions,
        kTeachingStyleOptions,
        kDayOptions,
        kLanguageOptions;
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/services/sound_service.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/utils/schedule_format.dart';
import 'package:palturo/utils/friendly_error.dart';
import 'package:palturo/onboarding/skill_options.dart'
    show onboardingInterestLabel;
import 'package:palturo/widgets/app_chrome.dart';
import 'package:palturo/widgets/app_feedback.dart';
import 'package:palturo/widgets/profile_completion_card.dart';
import 'package:palturo/widgets/top_labeled_field.dart';
import 'profile_data.dart';

const kBioMaxLength = 100;

class ProfileEditPage extends StatefulWidget {
  final ProfileData profile;

  /// Open with the Skills section at the top (Profile page shortcut).
  final bool startAtSkills;

  /// Injectable for tests; production builds use the Supabase-backed service.
  final ProfileService? profileService;

  const ProfileEditPage({
    super.key,
    required this.profile,
    this.startAtSkills = false,
    this.profileService,
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final ProfileService _profileService;
  bool _isSaving = false;
  String? _saveStatus;
  String? _savePhaseMessage;
  Timer? _saveProgressTimer;
  int _savePhaseIndex = 0;
  static const List<String> _saveMessages = [
    'Saving your profile...',
    'Preparing your card and notes...',
    'Teaching the matcher about your skills...',
    'Looking for people who fit what you offer...',
    'Still working. Good matches take a moment.',
  ];
  bool _showingProfileError = false;

  late final TextEditingController _bioController;
  late final TextEditingController _ageController;
  String? _gender;

  late Map<String, String> _availability;
  late List<String> _languages;
  late List<String> _learningStyles;
  late List<String> _teachingStyles;
  List<String?> _photos = [null];

  late List<String> _learningSkillIds;
  late List<String> _teachingSkillIds;
  late Map<String, String> _learningNotes;
  late Map<String, String> _teachingNotes;
  late Map<String, String> _initialLearningNotes;
  late Map<String, String> _initialTeachingNotes;
  final Set<String> _changedLearningNotes = {};
  final Set<String> _changedTeachingNotes = {};
  final GlobalKey _teachingSkillsKey = GlobalKey();
  final GlobalKey _learningSkillsKey = GlobalKey();
  final GlobalKey _skillsSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    assert(
      widget.profile.id.isNotEmpty,
      'ProfileEditPage requires a profile loaded from the server',
    );
    _profileService = widget.profileService ?? ProfileService();
    _bioController = TextEditingController(text: widget.profile.bio);
    _ageController = TextEditingController(
      text: widget.profile.age?.toString() ?? '',
    );
    _gender = widget.profile.gender;
    _availability = _parseAvailability(widget.profile);
    _languages = List.from(widget.profile.languages);
    _learningStyles = List.from(widget.profile.interests);
    _teachingStyles = List.from(widget.profile.teachingStyles);
    _learningSkillIds = List.from(widget.profile.learningSkillIds);
    _teachingSkillIds = List.from(widget.profile.teachingSkillIds);
    _learningNotes = Map<String, String>.from(widget.profile.learningNotes);
    _teachingNotes = Map<String, String>.from(widget.profile.teachingNotes);
    _initialLearningNotes = Map<String, String>.from(
      widget.profile.learningNotes,
    );
    _initialTeachingNotes = Map<String, String>.from(
      widget.profile.teachingNotes,
    );
    _photos = [
      widget.profile.photos.isNotEmpty ? widget.profile.photos.first : null,
    ];
    _teachingSkillImages = Map<String, String>.from(
      widget.profile.teachingSkillImages,
    );
    if (widget.startAtSkills) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSkills());
    }
  }

  @override
  void dispose() {
    _stopSaveProgress();
    _bioController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  late Map<String, String> _teachingSkillImages;
  final Map<String, String> _pendingTeachingImages = {};

  /// Skill rows whose pending pick is a video. Web blob paths carry no
  /// extension, so the editor has to remember what the picker returned.
  final Set<String> _showcaseVideos = {};

  Future<void> _pickAttachmentForSkill(String skillId) async {
    final picker = ImagePicker();
    final picked = await picker.pickMedia(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted || !_teachingSkillIds.contains(skillId)) {
      return;
    }

    final looksVideo =
        RegExp(
          r'\.(mp4|mov|webm|m4v)$',
          caseSensitive: false,
        ).hasMatch(picked.name) ||
        (picked.mimeType ?? '').startsWith('video/');
    final size = await picked.length();
    if (!mounted || !_teachingSkillIds.contains(skillId)) return;
    final limit = looksVideo ? 50 * 1024 * 1024 : 20 * 1024 * 1024;
    if (size > limit) {
      if (!mounted) return;
      showAppError(
        context,
        '${looksVideo ? 'Video' : 'Image'} is too large. Choose one under '
        '${looksVideo ? 50 : 20} MB.',
      );
      return;
    }

    setState(() {
      _pendingTeachingImages.remove(skillId);
      _teachingSkillImages[skillId] = picked.path;
      if (looksVideo) {
        _showcaseVideos.add(skillId);
      } else {
        _showcaseVideos.remove(skillId);
      }
    });
  }

  void _removeAttachmentForSkill(String skillId) {
    setState(() {
      _teachingSkillImages.remove(skillId);
      _showcaseVideos.remove(skillId);
    });
  }

  /// A skill row clears to an empty id before the user picks a replacement.
  /// Keep its proof under a pending key so the replacement can inherit it.
  void _replaceTeachingImage(String oldId, String newId) {
    if (oldId.isEmpty && newId.isEmpty) return;

    if (oldId == newId) {
      final pendingImage = _pendingTeachingImages.remove(oldId);
      if (pendingImage != null) {
        _teachingSkillImages[oldId] = pendingImage;
      }
      return;
    }

    if (newId.isEmpty) {
      final image = _teachingSkillImages.remove(oldId);
      if (image != null) _pendingTeachingImages[oldId] = image;
      return;
    }

    // If the target skill already has a proof waiting, keep it and leave the
    // old proof pending. Moving the old image here would overwrite the
    // target's own proof and delete it on save.
    if (_pendingTeachingImages.containsKey(newId)) return;

    final image =
        _pendingTeachingImages.remove(oldId) ??
        _teachingSkillImages.remove(oldId);
    if (image != null && !_teachingSkillImages.containsKey(newId)) {
      _teachingSkillImages[newId] = image;
      if (_showcaseVideos.remove(oldId)) _showcaseVideos.add(newId);
    }
  }

  void _removeTeachingImage(String skillId) {
    _teachingSkillImages.remove(skillId);
    _pendingTeachingImages.remove(skillId);
    _showcaseVideos.remove(skillId);
  }

  Map<String, String> _parseAvailability(dynamic source) {
    List<String> days;
    if (source is ProfileData) {
      days =
          source.availableDays.isNotEmpty
              ? source.availableDays
              : parseAvailableDays(source.schedule);
    } else {
      days = parseAvailableDays(source);
    }
    return {for (final d in days) d: 'Available'};
  }

  bool _hasUnsavedChanges() {
    final initialAvail = _parseAvailability(widget.profile);

    if (_bioController.text.trim() != widget.profile.bio.trim()) return true;
    if (_ageController.text.trim() != (widget.profile.age?.toString() ?? '')) {
      return true;
    }
    if (_gender != widget.profile.gender) return true;
    if (!setEquals(_availability.keys.toSet(), initialAvail.keys.toSet())) {
      return true;
    }
    if (!listEquals(_languages, widget.profile.languages)) return true;
    if (!listEquals(_learningStyles, widget.profile.interests)) return true;
    if (!listEquals(_teachingStyles, widget.profile.teachingStyles)) {
      return true;
    }
    if (!listEquals(_learningSkillIds, widget.profile.learningSkillIds)) {
      return true;
    }
    if (!listEquals(_teachingSkillIds, widget.profile.teachingSkillIds)) {
      return true;
    }
    if (!mapEquals(_learningNotes, widget.profile.learningNotes)) return true;
    if (!mapEquals(_teachingNotes, widget.profile.teachingNotes)) return true;

    final initialPhotos = widget.profile.photos;
    if (!listEquals(_photos, initialPhotos)) return true;

    final initialProofImages = widget.profile.teachingSkillImages;
    if (!mapEquals(_teachingSkillImages, initialProofImages)) return true;

    return false;
  }

  String get _genderLabel => switch (_gender) {
    'woman' => 'Woman',
    'man' => 'Man',
    'nonbinary' => 'Non-binary',
    'prefer_not_to_say' => 'Prefer not to say',
    _ => '',
  };

  Future<void> _pickGender() async {
    const options = <({String value, String label})>[
      (value: 'woman', label: 'Woman'),
      (value: 'man', label: 'Man'),
      (value: 'nonbinary', label: 'Non-binary'),
      (value: 'prefer_not_to_say', label: 'Prefer not to say'),
      (value: '', label: 'Not specified'),
    ];
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.elevatedSurface(context),
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Text(
                    'Gender',
                    style: AppTextStyles.headingText.copyWith(
                      color: Theme.of(sheetContext).colorScheme.secondary,
                      fontSize: 18,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Private. Used only for aggregate analytics.',
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.mutedText(sheetContext),
                      fontSize: 12,
                    ),
                  ),
                ),
                for (final option in options)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(
                      option.label,
                      style: AppTextStyles.regularText.copyWith(
                        color: Theme.of(sheetContext).colorScheme.secondary,
                      ),
                    ),
                    trailing:
                        _gender == (option.value.isEmpty ? null : option.value)
                            ? Icon(
                              Icons.check_circle_outline,
                              color: AppColors.accentText(sheetContext),
                            )
                            : null,
                    onTap: () => Navigator.pop(sheetContext, option.value),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
    if (result == null || !mounted) return;
    setState(() => _gender = result.isEmpty ? null : result);
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges()) return true;
    return showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your edits have not been saved.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
  }

  bool get _needsShowcaseReminder =>
      _teachingSkillIds.isNotEmpty && !_hasAnyShowcase(_teachingSkillImages);

  OnboardingRole? get _derivedRole => roleForSkills(
    hasLearning: _learningSkillIds.isNotEmpty,
    hasTeaching: _teachingSkillIds.isNotEmpty,
  );

  bool _hasAnyShowcase(Map<String, String> images) =>
      images.values.any((value) => value.trim().isNotEmpty);

  /// Reminds a mentor that no showcase keeps the profile out of discovery.
  /// Used when leaving the editor; saving has its own combined reminder.
  Future<bool> _confirmShowcaseReminder() async {
    if (_teachingSkillIds.isEmpty || _hasAnyShowcase(_teachingSkillImages)) {
      return true;
    }

    final add = await showConfirmDialog(
      context,
      title: 'Add a showcase?',
      message:
          'None of your teaching skills has a showcase yet. Your mentor '
          'profile will not appear in For You, Browse, or Explore until you '
          'add at least one.',
      confirmLabel: 'Add showcase',
      cancelLabel: 'Leave anyway',
      destructive: false,
    );
    if (!add) return true;
    await _scrollToTeachingSkills();
    return false;
  }

  Future<void> _scrollToTeachingSkills() async {
    final target = _teachingSkillsKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _scrollToLearningSkills() async {
    final target = _learningSkillsKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _scrollToSkills() async {
    final target = _skillsSectionKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      alignment: 0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  /// Learning notes block the save; teaching notes stay a reminder.
  Future<void> _showMissingLearningNotesDialog(List<String> labels) async {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final shown = labels.take(4).toList(growable: false);
    final extra = labels.length - shown.length;

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: AppColors.elevatedSurface(dialogContext),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.edit_note_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Learning notes required',
                    style: AppTextStyles.boldText.copyWith(
                      color: textTheme,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Add a note for ${shown.join(', ')}'
              '${extra > 0 ? ' and $extra more' : ''} before saving. '
              'Every learning skill needs a note so Pals know what you want '
              'to learn.',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Review notes',
                  style: AppTextStyles.boldText.copyWith(
                    color: AppColors.accentText(dialogContext),
                  ),
                ),
              ),
            ],
          ),
    );
    if (!mounted) return;
    await _scrollToLearningSkills();
  }

  /// Teaching notes and a missing showcase are reminders, not blockers.
  /// Returns true when the user chooses to save anyway.
  Future<bool> _confirmSaveReminder({
    required List<String> missingNoteLabels,
    required bool learningFirst,
  }) async {
    final needsShowcase = _needsShowcaseReminder;
    if (missingNoteLabels.isEmpty && !needsShowcase) return true;

    final textTheme = Theme.of(context).colorScheme.secondary;
    final shown = missingNoteLabels.take(4).toList(growable: false);
    final extra = missingNoteLabels.length - shown.length;
    final lines = <String>[
      if (missingNoteLabels.isNotEmpty)
        'Add a note for ${shown.join(', ')}'
            '${extra > 0 ? ' and $extra more' : ''}. '
            'It appears on your card.',
      if (needsShowcase)
        'Add a showcase to a teaching skill so learners can find you in '
            'Browse and For You.',
    ];

    final saveAnyway = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: AppColors.elevatedSurface(dialogContext),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.playlist_add_check_circle_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A few details are missing',
                    style: AppTextStyles.boldText.copyWith(
                      color: textTheme,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              '${lines.join('\n\n')}\n\n'
              'You can save now and finish these later. Your profile stays '
              'marked incomplete until they are filled in.',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  'Review',
                  style: AppTextStyles.boldText.copyWith(
                    color: AppColors.accentText(dialogContext),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  'Save anyway',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(dialogContext),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
    if (saveAnyway == true) return true;
    if (!mounted) return false;
    if (learningFirst) {
      await _scrollToLearningSkills();
    } else {
      await _scrollToTeachingSkills();
    }
    return false;
  }

  Future<void> _handleBack() async {
    if (_isSaving) return;
    if (_hasUnsavedChanges()) {
      final canDiscard = await _confirmDiscardChanges();
      if (!canDiscard || !mounted) return;
    }
    if (!await _confirmShowcaseReminder()) return;
    if (mounted) Navigator.of(context).pop();
  }

  ButtonStyle get _doneButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.black,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  );

  Future<void> _pickSchedule() async {
    final tempAvail = Map<String, String>.from(_availability);
    final secondary = Theme.of(context).colorScheme.secondary;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.elevatedSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Availability',
                      style: AppTextStyles.boldText.copyWith(color: secondary),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final day in kDayOptions)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.primary,
                              checkColor: Colors.black,
                              value: tempAvail.containsKey(day),
                              title: Text(
                                day,
                                style: AppTextStyles.regularText.copyWith(
                                  color: secondary,
                                ),
                              ),
                              onChanged: (checked) {
                                setModalState(() {
                                  if (checked == true) {
                                    tempAvail[day] = 'Available';
                                  } else {
                                    tempAvail.remove(day);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: _doneButtonStyle,
                        onPressed: () => Navigator.pop(context, tempAvail),
                        child: const Text(
                          'Apply',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _availability = result);
    }
  }

  Future<void> _pickMultiSelect({
    required String title,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onSaved,
  }) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: AppColors.elevatedSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final secondary = Theme.of(context).colorScheme.secondary;
        var tempSelected = List<String>.from(selected);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.boldText.copyWith(color: secondary),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final option in options)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.primary,
                              checkColor: Colors.black,
                              value: tempSelected.contains(option),
                              title: Text(
                                option,
                                style: AppTextStyles.regularText.copyWith(
                                  color: secondary,
                                ),
                              ),
                              onChanged: (checked) {
                                setModalState(() {
                                  if (checked == true) {
                                    tempSelected.add(option);
                                  } else {
                                    tempSelected.remove(option);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: _doneButtonStyle,
                        onPressed: () => Navigator.pop(context, tempSelected),
                        child: const Text(
                          'Apply',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null) onSaved(result);
  }

  Future<void> _showIncompleteSkillDialog(
    String message, {
    String title = 'Skill Incomplete',
  }) async {
    final textTheme = Theme.of(context).colorScheme.secondary;

    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.elevatedSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.boldText.copyWith(
                      color: textTheme,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: AppTextStyles.boldText.copyWith(
                    color: AppColors.accentText(context),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showProfileUnavailableDialog() async {
    final textTheme = Theme.of(context).colorScheme.secondary;

    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.elevatedSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Profile Not Loaded',
              style: AppTextStyles.boldText.copyWith(
                color: textTheme,
                fontSize: 18,
              ),
            ),
            content: Text(
              'We could not load your profile, so nothing was saved. '
              'Go back and try again.',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: AppTextStyles.boldText.copyWith(
                    color: AppColors.accentText(context),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showAgeRangeDialog(int? age) async {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final message =
        age != null && age < 18
            ? 'PalTuro is for people 18 and older. Please enter an age of 18 '
                'or above.'
            : age != null && age > 120
            ? 'Please enter an age of 120 or less.'
            : 'Please enter a valid age between 18 and 120.';

    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.elevatedSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Check your age',
              style: AppTextStyles.boldText.copyWith(
                color: textTheme,
                fontSize: 18,
              ),
            ),
            content: Text(
              message,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: AppTextStyles.boldText.copyWith(
                    color: AppColors.accentText(context),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  ProfileData _draftProfile() {
    final selectedDays = parseAvailableDays(_availability.keys);
    final parsedAge = int.tryParse(_ageController.text.trim());
    return widget.profile.copyWith(
      bio: _bioController.text.trim(),
      age: parsedAge,
      clearAge: parsedAge == null,
      gender: _gender,
      clearGender: _gender == null,
      schedule: formatScheduleDays(selectedDays),
      availableDays: selectedDays,
      languages: _languages,
      interests: _learningStyles,
      teachingStyles: _teachingStyles,
      role: _derivedRole,
      avatarUrl: _photos.isNotEmpty ? _photos.first : null,
      clearAvatar: _photos.isEmpty || (_photos.first?.trim().isEmpty ?? true),
      photos: [_photos.isNotEmpty ? _photos.first : null],
      learningSkillIds: _learningSkillIds,
      teachingSkillIds: _teachingSkillIds,
      learningNotes: _learningNotes,
      teachingNotes: _teachingNotes,
      changedLearningNotes: Set<String>.from(_changedLearningNotes),
      changedTeachingNotes: Set<String>.from(_changedTeachingNotes),
    );
  }

  void _openPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProfilePreviewPage(profile: _draftProfile()),
      ),
    );
  }

  /// Drops skills the classifier rejected so they cannot be saved later. A
  /// fresh list/map instance is required: `SkillsCard` only reloads when the
  /// `initialSkillIds` reference changes.
  void _dropRejectedSkills(SkillModerationException error) {
    if (error.skills.isEmpty) return;
    final learning = List<String>.from(_learningSkillIds);
    final teaching = List<String>.from(_teachingSkillIds);
    final teachingImages = Map<String, String>.from(_teachingSkillImages);
    for (final rejected in error.skills) {
      final id = rejected.skillId;
      if (id.isEmpty) continue;
      if (rejected.kind == 'learn') {
        learning.remove(id);
        _learningNotes.remove(id);
        _changedLearningNotes.remove(id);
      } else {
        teaching.remove(id);
        _teachingNotes.remove(id);
        _changedTeachingNotes.remove(id);
        teachingImages.remove(id);
        _pendingTeachingImages.remove(id);
      }
    }
    setState(() {
      _learningSkillIds = learning;
      _teachingSkillIds = teaching;
      _teachingSkillImages = teachingImages;
    });
  }

  Future<void> _showSkillRejectedDialog(String message) async {
    final textTheme = Theme.of(context).colorScheme.secondary;

    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.elevatedSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.block_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Skill not added',
                    style: AppTextStyles.boldText.copyWith(
                      color: textTheme,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: AppTextStyles.boldText.copyWith(
                    color: AppColors.accentText(context),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _startSaveProgress() {
    _saveProgressTimer?.cancel();
    _savePhaseIndex = 0;
    _savePhaseMessage = _saveMessages.first;
    _saveProgressTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _savePhaseIndex = (_savePhaseIndex + 1).clamp(
          0,
          _saveMessages.length - 1,
        );
        _savePhaseMessage = _saveMessages[_savePhaseIndex];
      });
    });
  }

  void _stopSaveProgress() {
    _saveProgressTimer?.cancel();
    _saveProgressTimer = null;
  }

  Future<void> _save() async {
    if (widget.profile.id.isEmpty) {
      if (_showingProfileError) return;
      _showingProfileError = true;
      try {
        await _showProfileUnavailableDialog();
      } finally {
        _showingProfileError = false;
      }
      return;
    }

    // Keep both skill sets regardless of the visible role. Switching roles
    // hides one side of the editor; it must not silently delete that work.
    final learningSkills = _learningSkillIds;
    final teachingSkills = _teachingSkillIds;
    final teachingSkillImages = _teachingSkillImages;

    final allSelectedSkills = [...learningSkills, ...teachingSkills];
    for (final skill in allSelectedSkills) {
      final lower = skill.trim().toLowerCase();
      if (lower == 'other' || lower == 'others') {
        await _showIncompleteSkillDialog(
          'Please name and pick a category for your skill.',
        );
        return;
      }
      final custom = CustomSkill.tryParse(skill);
      if (custom != null && !custom.isValid) {
        await _showIncompleteSkillDialog(
          'Please enter a skill name and select a category.',
        );
        return;
      }
    }

    final ageText = _ageController.text.trim();
    final ageValue = int.tryParse(ageText);
    if (ageText.isNotEmpty &&
        (ageValue == null || ageValue < 18 || ageValue > 120)) {
      await _showAgeRangeDialog(ageValue);
      return;
    }

    final missingLearningNotes = learningSkills
        .where((id) => (_learningNotes[id]?.trim() ?? '').isEmpty)
        .map(onboardingInterestLabel)
        .toList(growable: false);
    if (widget.profile.notesLoaded && missingLearningNotes.isNotEmpty) {
      await _showMissingLearningNotesDialog(missingLearningNotes);
      return;
    }

    final missingTeachingNotes = teachingSkills
        .where((id) => (_teachingNotes[id]?.trim() ?? '').isEmpty)
        .map(onboardingInterestLabel)
        .toList(growable: false);
    final missingNoteLabels = [
      ...missingLearningNotes,
      ...missingTeachingNotes,
    ];
    if (!await _confirmSaveReminder(
      missingNoteLabels: missingNoteLabels,
      learningFirst: missingLearningNotes.isNotEmpty,
    )) {
      return;
    }
    if (!mounted) return;

    final selectedDays = parseAvailableDays(_availability.keys);
    final scheduleFormatted = formatScheduleDays(selectedDays);
    final parsedAge = int.tryParse(_ageController.text.trim());

    final updated = widget.profile.copyWith(
      bio: _bioController.text.trim(),
      age: parsedAge,
      clearAge: parsedAge == null,
      gender: _gender,
      clearGender: _gender == null,
      schedule: scheduleFormatted,
      availableDays: selectedDays,
      languages: _languages,
      interests: _learningStyles,
      teachingStyles: _teachingStyles,
      role: roleForSkills(
        hasLearning: learningSkills.isNotEmpty,
        hasTeaching: teachingSkills.isNotEmpty,
      ),
      avatarUrl: _photos.isNotEmpty ? _photos.first : null,
      clearAvatar: _photos.isEmpty || (_photos.first?.trim().isEmpty ?? true),
      photos: [_photos.isNotEmpty ? _photos.first : null],
      learningSkillIds: learningSkills,
      teachingSkillIds: teachingSkills,
      learningNotes: _learningNotes,
      teachingNotes: _teachingNotes,
      changedLearningNotes: Set<String>.from(_changedLearningNotes),
      changedTeachingNotes: Set<String>.from(_changedTeachingNotes),
    );

    setState(() {
      _isSaving = true;
      _saveStatus = null;
      _savePhaseMessage = _saveMessages.first;
    });
    _startSaveProgress();

    try {
      final savedProfile = await _profileService.updateProfile(
        updated,
        newPhotoLocalPaths: _photos,
        teachingSkillImages: teachingSkillImages,
        onClassifyingSkill: (skillName) {
          if (!mounted) return;
          setState(() {
            _saveStatus =
                'Adding “$skillName” to PalTuro…\n'
                'This can take up to 30 seconds.';
          });
        },
      );
      if (mounted) {
        _stopSaveProgress();
        Haptics.success();
        SoundService.instance.play(AppSound.success);
        Navigator.pop(context, savedProfile);
      }
    } catch (e) {
      Haptics.error();
      debugPrint('[ProfileEdit] save failed: $e');
      if (!mounted) return;
      if (e is SkillModerationException) {
        _dropRejectedSkills(e);
        // Rejected skills never reach the database, so the form must stop
        // showing them and explain why the save did not go through.
        setState(() {
          _isSaving = false;
          _saveStatus = null;
        });
        await _showSkillRejectedDialog(e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyError(
                e,
                fallback: 'Couldn’t save your profile. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      _stopSaveProgress();
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final lightColor = Theme.of(context).colorScheme.surface;

    final scheduleDisplay = formatScheduleDays(_availability.keys);

    final hasChanges = _hasUnsavedChanges();
    final canSave = hasChanges && !_isSaving;
    final needsShowcaseReminder = _needsShowcaseReminder;
    final wantsTeaching = _teachingSkillIds.isNotEmpty;
    final completion = computeProfileCompletion(_draftProfile());
    final hasPhoto =
        _photos.any((photo) => photo?.trim().isNotEmpty == true) ||
        widget.profile.avatarUrl?.trim().isNotEmpty == true;
    final aboutNeedsCompletion =
        _bioController.text.trim().isEmpty ||
        _languages.isEmpty ||
        _availability.isEmpty ||
        _learningStyles.isEmpty ||
        (wantsTeaching && _teachingStyles.isEmpty);
    final privateNeedsCompletion =
        _ageController.text.trim().isEmpty || _gender == null;
    final skillsNeedCompletion =
        (_learningSkillIds.isEmpty && _teachingSkillIds.isEmpty) ||
        completion.missing.any((item) => item.label == 'Skill notes');
    final largeText = MediaQuery.textScalerOf(context).scale(20) > 28;

    return PopScope(
      canPop: !hasChanges && !_isSaving && !needsShowcaseReminder,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isSaving) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: lightColor,
        appBar: AppChrome.appBar(
          leading: AppChrome.iconAction(
            icon: Icons.arrow_back_ios_new,
            tooltip: 'Back',
            color: textTheme,
            size: 16,
            onPressed: _handleBack,
          ),
          title: Text(
            largeText ? 'Edit' : 'Edit Profile',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headingText.copyWith(
              color: textTheme,
              fontSize: 20,
            ),
          ),
          actions: [
            AppChrome.iconAction(
              icon: Icons.visibility_outlined,
              tooltip: 'Preview profile',
              onPressed: _isSaving ? null : _openPreview,
              color: textTheme,
            ),
            if (hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  label: 'Unsaved changes',
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor:
                    canSave
                        ? AppColors.primary
                        : AppColors.mutedSurface(context),
                foregroundColor:
                    canSave ? Colors.black : AppColors.mutedText(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
              ),
              onPressed: canSave ? _save : null,
              child: Text(
                'Save',
                style: AppTextStyles.regularText.copyWith(
                  color: canSave ? Colors.black : AppColors.mutedText(context),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  if (!completion.isComplete)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: ProfileCompletionCard(
                        completion: completion,
                        onEdit: () {},
                        showAction: false,
                        compact: true,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ProfileSectionHeader(
                      title: 'Profile photos',
                      needsAttention: !hasPhoto,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PhotoPickerRow(
                      photoPaths: _photos,
                      onChanged: (updated) {
                        if (!mounted) return;
                        setState(() => _photos = updated);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ProfileSectionHeader(
                      title: 'About you',
                      needsAttention: aboutNeedsCompletion,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Bio',
                      style: AppTextStyles.boldText.copyWith(
                        color: textTheme,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding:
                          _bioController.text.trim().isEmpty
                              ? const EdgeInsets.symmetric(horizontal: 8)
                              : EdgeInsets.zero,
                      decoration:
                          _bioController.text.trim().isEmpty
                              ? BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              )
                              : null,
                      child: TopLabeledField(
                        label: 'Introduce yourself',
                        controller: _bioController,
                        onChanged: (_) => setState(() {}),
                        maxLines: null,
                        maxLength: kBioMaxLength,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DropdownInfoField(
                          icon: Icons.calendar_today_outlined,
                          label: 'Availability',
                          value: scheduleDisplay,
                          hint: 'Tap to set availability',
                          onTap: _pickSchedule,
                          needsAttention: _availability.isEmpty,
                        ),
                        const SizedBox(height: 12),
                        _DropdownInfoField(
                          icon: Icons.translate,
                          label: 'Language',
                          value: _languages.join(', '),
                          hint: 'Tap to set languages',
                          needsAttention: _languages.isEmpty,
                          onTap:
                              () => _pickMultiSelect(
                                title: 'Language Preference',
                                options: kLanguageOptions,
                                selected: _languages,
                                onSaved:
                                    (result) =>
                                        setState(() => _languages = result),
                              ),
                        ),
                        const SizedBox(height: 12),
                        _DropdownInfoField(
                          icon: Icons.psychology,
                          label: 'Learning Style',
                          value: _learningStyles.join(', '),
                          hint: 'Tap to set learning styles',
                          needsAttention: _learningStyles.isEmpty,
                          onTap:
                              () => _pickMultiSelect(
                                title: 'Learning Style',
                                options: kLearningStyleOptions,
                                selected: _learningStyles,
                                onSaved:
                                    (result) => setState(
                                      () => _learningStyles = result,
                                    ),
                              ),
                        ),
                        const SizedBox(height: 12),
                        _DropdownInfoField(
                          icon: Icons.school_outlined,
                          label: 'Teaching Style',
                          value: _teachingStyles.join(', '),
                          hint: 'Tap to set teaching styles',
                          needsAttention:
                              wantsTeaching && _teachingStyles.isEmpty,
                          onTap:
                              () => _pickMultiSelect(
                                title: 'Teaching Style',
                                options: kTeachingStyleOptions,
                                selected: _teachingStyles,
                                onSaved:
                                    (result) => setState(
                                      () => _teachingStyles = result,
                                    ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileSectionHeader(
                          title: 'Private details',
                          needsAttention: privateNeedsCompletion,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Only used for aggregate analytics. Never shown on '
                          'your profile, cards, or public matches.',
                          style: AppTextStyles.regularText.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 88,
                              child: Container(
                                padding:
                                    _ageController.text.trim().isEmpty
                                        ? const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        )
                                        : EdgeInsets.zero,
                                decoration:
                                    _ageController.text.trim().isEmpty
                                        ? BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        )
                                        : null,
                                child: TopLabeledField(
                                  label: 'Age',
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DropdownInfoField(
                                icon: Icons.person_outline,
                                label: 'Gender',
                                value: _genderLabel,
                                hint: 'Select gender',
                                onTap: _pickGender,
                                needsAttention: _gender == null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.8,
                            child: Divider(
                              color: textTheme.withValues(alpha: 0.2),
                              thickness: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        KeyedSubtree(
                          key: _skillsSectionKey,
                          child: _ProfileSectionHeader(
                            title: 'Skills',
                            needsAttention: skillsNeedCompletion,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _derivedRole == null
                                    ? 'Add a skill to set your role.'
                                    : 'You appear as '
                                        '${_derivedRole!.displayLabel}. '
                                        'Your role updates with your skills.',
                                style: AppTextStyles.regularText.copyWith(
                                  color: AppColors.mutedText(context),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _learningSkillsKey,
                          child: SkillsCard.toLearn(
                            isEditing: true,
                            initialSkillIds: _learningSkillIds,
                            notes: _learningNotes,
                            onChanged:
                                (updatedIds) => setState(
                                  () => _learningSkillIds = updatedIds,
                                ),
                            onNoteChanged: (id, note) {
                              setState(() {
                                if (note.trim().isEmpty) {
                                  _learningNotes.remove(id);
                                } else {
                                  _learningNotes[id] = note;
                                }
                                final initial = _initialLearningNotes[id] ?? '';
                                final current = _learningNotes[id] ?? '';
                                if (current.trim() == initial.trim()) {
                                  _changedLearningNotes.remove(id);
                                } else {
                                  _changedLearningNotes.add(id);
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        KeyedSubtree(
                          key: _teachingSkillsKey,
                          child: SkillsCard.toTeach(
                            isEditing: true,
                            initialSkillIds: _teachingSkillIds,
                            attachments: _teachingSkillImages,
                            videoAttachments: _showcaseVideos,
                            notes: _teachingNotes,
                            onNoteChanged: (id, note) {
                              setState(() {
                                if (note.trim().isEmpty) {
                                  _teachingNotes.remove(id);
                                } else {
                                  _teachingNotes[id] = note;
                                }
                                final initial = _initialTeachingNotes[id] ?? '';
                                final current = _teachingNotes[id] ?? '';
                                if (current.trim() == initial.trim()) {
                                  _changedTeachingNotes.remove(id);
                                } else {
                                  _changedTeachingNotes.add(id);
                                }
                              });
                            },
                            onChanged: (updatedIds) {
                              setState(() {
                                // A proof can be waiting while a row has no
                                // selection; restore it if that skill is
                                // re-added through another row.
                                for (final entry
                                    in _pendingTeachingImages.entries
                                        .toList()) {
                                  if (updatedIds.contains(entry.key)) {
                                    if (!_teachingSkillImages.containsKey(
                                      entry.key,
                                    )) {
                                      _teachingSkillImages[entry.key] =
                                          entry.value;
                                    }
                                    _pendingTeachingImages.remove(entry.key);
                                  }
                                }
                                final removed =
                                    _teachingSkillIds
                                        .where((id) => !updatedIds.contains(id))
                                        .toList();
                                for (final oldId in removed) {
                                  if (_pendingTeachingImages.containsKey(
                                    oldId,
                                  )) {
                                    continue;
                                  }
                                  _teachingSkillImages.remove(oldId);
                                }
                                _teachingSkillIds = updatedIds;
                              });
                            },
                            onSkillReplaced: _replaceTeachingImage,
                            onSkillRemoved: _removeTeachingImage,
                            onAttachFile:
                                (skillId) => _pickAttachmentForSkill(skillId),
                            onRemoveAttachment:
                                (skillId) => _removeAttachmentForSkill(skillId),
                          ),
                        ),
                        if (wantsTeaching) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Showcase media is managed on each teaching skill above.',
                            style: AppTextStyles.regularText.copyWith(
                              color: AppColors.mutedText(context),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            if (_isSaving)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                          strokeWidth: 3.5,
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _saveStatus ??
                                _savePhaseMessage ??
                                'Saving your profile...',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.boldText.copyWith(
                              color: textTheme,
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (_saveStatus == null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'This can take a moment while we prepare your '
                            'matches.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.regularText.copyWith(
                              color: AppColors.mutedText(context),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePreviewPage extends StatelessWidget {
  final ProfileData profile;

  const _ProfilePreviewPage({required this.profile});

  String get _roleLabel {
    switch (profile.effectiveRole) {
      case OnboardingRole.learn:
        return 'Learner';
      case OnboardingRole.teach:
        return 'Mentor';
      case OnboardingRole.both:
        return 'Learner & Mentor';
      case null:
        return 'Role not set';
    }
  }

  String? get _mainPhoto {
    if (profile.photos.isEmpty) return null;
    final main = profile.photos[0];
    return main != null && main.trim().isNotEmpty ? main : null;
  }

  ImageProvider? get _imageProvider {
    final path = _mainPhoto;
    if (path == null) return null;
    if (path.startsWith('http') || kIsWeb) return NetworkImage(path);
    return FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final schedule = formatScheduleDays(profile.availableDays);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppChrome.appBar(
        leading: AppChrome.backButton(context, color: textTheme),
        title: Text(
          'Profile preview',
          style: AppTextStyles.headingText.copyWith(
            color: textTheme,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 1.35,
              child:
                  _imageProvider != null
                      ? Image(
                        image: _imageProvider!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, _, _) =>
                                _PreviewPhotoFallback(name: profile.name),
                      )
                      : _PreviewPhotoFallback(name: profile.name),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            profile.name,
            style: AppTextStyles.headingText.copyWith(
              color: textTheme,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _roleLabel,
            style: AppTextStyles.boldText.copyWith(
              color: AppColors.accentText(context),
              fontSize: 13,
            ),
          ),
          if (profile.bio.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              profile.bio.trim(),
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.82),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _PreviewRow(
            icon: Icons.calendar_today_outlined,
            label: 'Availability',
            value: schedule.isEmpty ? 'Not set' : schedule,
          ),
          _PreviewRow(
            icon: Icons.translate,
            label: 'Languages',
            value:
                profile.languages.isEmpty
                    ? 'Not set'
                    : profile.languages.join(', '),
          ),
          _PreviewRow(
            icon: Icons.psychology_outlined,
            label: 'Learning style',
            value:
                profile.interests.isEmpty
                    ? 'Not set'
                    : profile.interests.join(', '),
          ),
          _PreviewRow(
            icon: Icons.menu_book_outlined,
            label: 'Skills to learn',
            value: '${profile.learningSkillIds.length} selected',
          ),
          _PreviewRow(
            icon: Icons.workspace_premium_outlined,
            label: 'Skills to teach',
            value: '${profile.teachingSkillIds.length} selected',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mutedSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Text(
              'This preview shows unsaved edits. Public cards also include your skill names, notes, and attached showcase media.',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.mutedText(context)),
          const SizedBox(width: 10),
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPhotoFallback extends StatelessWidget {
  final String name;

  const _PreviewPhotoFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? 'P' : name.trim().characters.first.toUpperCase();
    return Container(
      color: AppColors.mutedSurface(context),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.headingText.copyWith(
          color: AppColors.mutedText(context),
          fontSize: 44,
        ),
      ),
    );
  }
}

class _ProfileSectionHeader extends StatelessWidget {
  final String title;
  final bool needsAttention;

  const _ProfileSectionHeader({
    required this.title,
    this.needsAttention = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (needsAttention) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'NEEDS COMPLETION',
                style: AppTextStyles.boldText.copyWith(
                  color: AppColors.accentText(context),
                  fontSize: 8,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DropdownInfoField extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Future<void> Function() onTap;
  final bool needsAttention;

  const _DropdownInfoField({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.needsAttention = false,
  });

  @override
  State<_DropdownInfoField> createState() => _DropdownInfoFieldState();
}

class _DropdownInfoFieldState extends State<_DropdownInfoField> {
  bool _isOpen = false;

  Future<void> _handleTap() async {
    setState(() => _isOpen = true);
    await widget.onTap();
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final showHint = widget.value.isEmpty;

    return Semantics(
      container: true,
      button: true,
      label: '${widget.label}, ${showHint ? widget.hint : widget.value}',
      excludeSemantics: true,
      onTap: _handleTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Container(
          padding:
              widget.needsAttention
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : EdgeInsets.zero,
          decoration:
              widget.needsAttention
                  ? BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  )
                  : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(widget.icon, size: 18, color: textColor),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            showHint ? widget.hint : widget.value,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  showHint
                                      ? textColor.withValues(alpha: 0.4)
                                      : textColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _isOpen ? 0.5 : 0,
                          duration: AppMotion.base,
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPickerRow extends StatelessWidget {
  final List<String?> photoPaths;
  final ValueChanged<List<String?>> onChanged;

  const _PhotoPickerRow({required this.photoPaths, required this.onChanged});

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;
    onChanged([picked.path]);
  }

  void _removePhoto() {
    onChanged([null]);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        photoPaths.isNotEmpty && (photoPaths.first?.trim().isNotEmpty ?? false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: _PhotoSlot(
            path: photoPaths.isNotEmpty ? photoPaths.first : null,
            onTap: _pickPhoto,
            onRemove: _removePhoto,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Main photo',
                style: AppTextStyles.boldText.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Shown on your profile and discovery cards. Use a clear photo '
                'so Pals know who they are meeting.',
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.mutedText(context),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (hasPhoto)
                TextButton.icon(
                  onPressed: _pickPhoto,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 44),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: Icon(
                    Icons.photo_camera_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    'Change photo',
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.accentText(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final String? path;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PhotoSlot({
    required this.path,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = path != null && path!.isNotEmpty;
    final isNetwork = hasImage && path!.startsWith('http');

    ImageProvider? imageProvider;
    if (hasImage) {
      // Web: picked files arrive as blob: URLs. File() throws
      // "Unsupported operation: _Namespace" there, so never build a
      // FileImage on web; NetworkImage can load blob: and http(s) URLs.
      imageProvider =
          isNetwork || kIsWeb
              ? NetworkImage(path!) as ImageProvider
              : FileImage(File(path!));
    }

    return Semantics(
      container: true,
      button: true,
      label: hasImage ? 'Profile photo' : 'Add profile photo',
      hint: hasImage ? 'Change photo' : 'Add photo',
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: hasImage ? null : AppColors.mutedSurface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary, width: 3),
                  image:
                      imageProvider != null
                          ? DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    hasImage
                        ? null
                        : Center(
                          child: Icon(
                            Icons.add,
                            size: 32,
                            color: AppColors.mutedText(context),
                          ),
                        ),
              ),
              if (hasImage)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (hasImage)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Semantics(
                    container: true,
                    button: true,
                    label: 'Remove photo',
                    child: GestureDetector(
                      onTap: onRemove,
                      child: SizedBox(
                        width: AppSpacing.iconTarget,
                        height: AppSpacing.iconTarget,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
