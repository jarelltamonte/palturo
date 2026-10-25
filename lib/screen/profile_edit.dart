import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/widgets/role_card_group.dart';
import 'package:palturo/screen/card/skills_card.dart';
import 'package:palturo/onboarding/screens/onboarding_final_screen.dart'
    show kLearningStyleOptions, kDayOptions, kLanguageOptions;
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/utils/schedule_format.dart';
import 'package:palturo/widgets/top_labeled_field.dart';
import 'profile_data.dart';

const kBioMaxLength = 100;

class ProfileEditPage extends StatefulWidget {
  final ProfileData profile;

  const ProfileEditPage({super.key, required this.profile});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final ProfileService _profileService = ProfileService();
  bool _isSaving = false;
  bool _showingProfileError = false;

  late final TextEditingController _bioController;

  late Map<String, String> _availability;
  late List<String> _languages;
  late List<String> _learningStyles;
  List<String?> _photos = [null, null, null];

  OnboardingRole? _role;
  late List<String> _learningSkillIds;
  late List<String> _teachingSkillIds;
  late Map<String, String> _learningNotes;
  late Map<String, String> _teachingNotes;
  late Map<String, String> _initialLearningNotes;
  late Map<String, String> _initialTeachingNotes;
  final Set<String> _changedLearningNotes = {};
  final Set<String> _changedTeachingNotes = {};
  final GlobalKey _teachingSkillsKey = GlobalKey();

  static const _roleOptions = [
    RoleOption(
      OnboardingRole.learn,
      'assets/icons/rlearner.svg',
      'I want to\nlearn',
    ),
    RoleOption(
      OnboardingRole.teach,
      'assets/icons/rmentor.svg',
      'I want to\nteach',
    ),
    RoleOption(OnboardingRole.both, 'assets/icons/rboth.svg', 'I can do\nboth'),
  ];

  @override
  void initState() {
    super.initState();
    assert(
      widget.profile.id.isNotEmpty,
      'ProfileEditPage requires a profile loaded from the server',
    );
    _bioController = TextEditingController(text: widget.profile.bio);
    _availability = _parseAvailability(widget.profile);
    _languages = List.from(widget.profile.languages);
    _learningStyles = List.from(widget.profile.interests);
    _role = widget.profile.role;
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
    _photos = List.from(widget.profile.photos);
    _teachingSkillImages = Map<String, String>.from(
      widget.profile.teachingSkillImages,
    );
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  late Map<String, String> _teachingSkillImages;
  final Map<String, String> _pendingTeachingImages = {};

  Future<void> _pickAttachmentForSkill(String skillId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted || !_teachingSkillIds.contains(skillId)) {
      return;
    }

    setState(() {
      _pendingTeachingImages.remove(skillId);
      _teachingSkillImages[skillId] = picked.path;
    });
  }

  void _removeAttachmentForSkill(String skillId) {
    setState(() {
      _teachingSkillImages.remove(skillId);
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
    }
  }

  void _removeTeachingImage(String skillId) {
    _teachingSkillImages.remove(skillId);
    _pendingTeachingImages.remove(skillId);
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
    if (_role != widget.profile.role) return true;
    if (!setEquals(_availability.keys.toSet(), initialAvail.keys.toSet())) {
      return true;
    }
    if (!listEquals(_languages, widget.profile.languages)) return true;
    if (!listEquals(_learningStyles, widget.profile.interests)) return true;
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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

  Future<void> _showIncompleteSkillDialog(String message) async {
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
                Text(
                  'Skill Incomplete',
                  style: AppTextStyles.boldText.copyWith(
                    color: textTheme,
                    fontSize: 18,
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

  ProfileData _draftProfile() {
    final selectedDays = parseAvailableDays(_availability.keys);
    return widget.profile.copyWith(
      bio: _bioController.text.trim(),
      schedule: formatScheduleDays(selectedDays),
      availableDays: selectedDays,
      languages: _languages,
      interests: _learningStyles,
      role: _role,
      photos: _photos,
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

    final selectedDays = parseAvailableDays(_availability.keys);
    final scheduleFormatted = formatScheduleDays(selectedDays);

    final updated = widget.profile.copyWith(
      bio: _bioController.text.trim(),
      schedule: scheduleFormatted,
      availableDays: selectedDays,
      languages: _languages,
      interests: _learningStyles,
      role: _role,
      photos: _photos,
      learningSkillIds: learningSkills,
      teachingSkillIds: teachingSkills,
      learningNotes: _learningNotes,
      teachingNotes: _teachingNotes,
      changedLearningNotes: Set<String>.from(_changedLearningNotes),
      changedTeachingNotes: Set<String>.from(_changedTeachingNotes),
    );

    setState(() => _isSaving = true);

    try {
      final savedProfile = await _profileService.updateProfile(
        updated,
        newPhotoLocalPaths: _photos,
        teachingSkillImages: teachingSkillImages,
      );
      if (mounted) Navigator.pop(context, savedProfile);
    } catch (e) {
      debugPrint('[ProfileEdit] save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t save your profile. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final lightColor = Theme.of(context).colorScheme.surface;

    final scheduleDisplay = formatScheduleDays(_availability.keys);

    final hasChanges = _hasUnsavedChanges();
    final canSave = hasChanges && !_isSaving;
    final largeText = MediaQuery.textScalerOf(context).scale(20) > 28;

    return PopScope(
      canPop: !hasChanges && !_isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isSaving) return;
        final canDiscard = await _confirmDiscardChanges();
        if (canDiscard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: lightColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: textTheme),
          titleSpacing: 0,
          title: Text(
            largeText ? 'Edit' : 'Edit Profile',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headingText.copyWith(
              color: textTheme,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back_ios_new, color: textTheme, size: 16),
            onPressed: () async {
              if (_isSaving) return;
              if (_hasUnsavedChanges()) {
                final canDiscard = await _confirmDiscardChanges();
                if (canDiscard && context.mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Preview profile',
              onPressed: _isSaving ? null : _openPreview,
              icon: Icon(Icons.visibility_outlined, color: textTheme),
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
                      color: AppColors.accentText(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton(
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
                    color:
                        canSave ? Colors.black : AppColors.mutedText(context),
                  ),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _ProfileSectionHeader(title: 'Profile photos'),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _PhotoPickerRow(
                      photoPaths: _photos,
                      onChanged: (updated) {
                        if (!mounted) return;
                        setState(() => _photos = updated);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'The main photo appears on your profile and cards.',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.mutedText(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _ProfileSectionHeader(title: 'About you'),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DropdownInfoField(
                          icon: Icons.calendar_today_outlined,
                          label: 'Availability',
                          value: scheduleDisplay,
                          hint: 'Tap to set availability',
                          onTap: _pickSchedule,
                        ),
                        const SizedBox(height: 12),
                        _DropdownInfoField(
                          icon: Icons.translate,
                          label: 'Language',
                          value: _languages.join(', '),
                          hint: 'Tap to set languages',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                        const _ProfileSectionHeader(title: 'Role'),
                        const SizedBox(height: 10),
                        RoleCardGroup(
                          options: _roleOptions,
                          selected: _role,
                          isEditing: true,
                          onSelect: (role) => setState(() => _role = role),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Changing role hides skills; it does not delete them.',
                          style: AppTextStyles.regularText.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _ProfileSectionHeader(title: 'Skills'),
                        const SizedBox(height: 12),
                        if (_role == OnboardingRole.learn ||
                            _role == OnboardingRole.both) ...[
                          SkillsCard.toLearn(
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
                          const SizedBox(height: 24),
                        ],
                        if (_role == OnboardingRole.teach ||
                            _role == OnboardingRole.both)
                          KeyedSubtree(
                            key: _teachingSkillsKey,
                            child: SkillsCard.toTeach(
                              isEditing: true,
                              initialSkillIds: _teachingSkillIds,
                              attachments: _teachingSkillImages,
                              notes: _teachingNotes,
                              onNoteChanged: (id, note) {
                                setState(() {
                                  if (note.trim().isEmpty) {
                                    _teachingNotes.remove(id);
                                  } else {
                                    _teachingNotes[id] = note;
                                  }
                                  final initial =
                                      _initialTeachingNotes[id] ?? '';
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
                                          .where(
                                            (id) => !updatedIds.contains(id),
                                          )
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
                                  (skillId) =>
                                      _removeAttachmentForSkill(skillId),
                            ),
                          ),
                        const SizedBox(height: 24),
                        const _ProfileSectionHeader(title: 'Showcase'),
                        const SizedBox(height: 8),
                        Text(
                          _role == OnboardingRole.teach ||
                                  _role == OnboardingRole.both
                              ? 'Showcase media is attached to a teaching skill. Use Attach a file on a teaching skill above to add it.'
                              : 'Switch to Teach or Both to add showcase media to a teaching skill.',
                          style: AppTextStyles.regularText.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        if (_role == OnboardingRole.teach ||
                            _role == OnboardingRole.both) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () async {
                              final target = _teachingSkillsKey.currentContext;
                              if (target == null) return;
                              await Scrollable.ensureVisible(
                                target,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: const Text('Manage teaching showcase'),
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
                        Text(
                          'Saving profile...',
                          style: AppTextStyles.boldText.copyWith(
                            color: textTheme,
                            fontSize: 15,
                          ),
                        ),
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
    switch (profile.role) {
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: 16, color: textTheme),
        ),
        title: Text(
          'Profile preview',
          style: AppTextStyles.headingText.copyWith(
            color: textTheme,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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

  const _ProfileSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.regularText.copyWith(
          color: AppColors.mutedText(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
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

  const _DropdownInfoField({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
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
    );
  }
}

class _PhotoPickerRow extends StatelessWidget {
  final List<String?> photoPaths;
  final ValueChanged<List<String?>> onChanged;

  const _PhotoPickerRow({required this.photoPaths, required this.onChanged});

  Future<void> _pickPhoto(int index) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final updated = List<String?>.from(photoPaths);
    while (updated.length <= index) {
      updated.add(null);
    }
    updated[index] = picked.path;
    onChanged(updated);
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= photoPaths.length) return;
    final updated = List<String?>.from(photoPaths);
    updated[index] = null;
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: _PhotoSlot(
              index: i,
              path: photoPaths.length > i ? photoPaths[i] : null,
              onTap: () => _pickPhoto(i),
              onRemove: () => _removePhoto(i),
            ),
          ),
          if (i != 2) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final int index;
  final String? path;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PhotoSlot({
    required this.index,
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

    final slotLabel =
        hasImage
            ? (index == 0 ? 'Main photo' : 'Photo ${index + 1}')
            : (index == 0
                ? 'Add main photo'
                : index == 1
                ? 'Add second photo'
                : 'Add third photo');

    return Semantics(
      container: true,
      button: true,
      label: slotLabel,
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
              if (index == 0)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const ExcludeSemantics(
                      child: Text(
                        'MAIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
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
                        width: 44,
                        height: 44,
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
