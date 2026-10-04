import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/widgets/role_card_group.dart';
import 'package:palturo/onboarding/widgets/onboarding_select_field.dart';
import 'package:palturo/screen/card/skills_card.dart';
import 'package:palturo/onboarding/screens/onboarding_final_screen.dart'
    show kLearningStyleOptions, kDayOptions, kLanguageOptions;
import 'profile_data.dart';

class ProfileEditPage extends StatefulWidget {
  final ProfileData profile;

  const ProfileEditPage({
    super.key,
    required this.profile,
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late String _schedulePlaceholder;
  late String _languagesPlaceholder;
  late String _learningStylesPlaceholder;

  List<String> _schedule = [];
  List<String> _languages = [];
  List<String> _learningStyles = [];
  List<String?> _photos = [null, null, null];

  OnboardingRole? _role;
  late List<String> _learningSkillIds;
  late List<String> _teachingSkillIds;

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
    RoleOption(
      OnboardingRole.both,
      'assets/icons/rboth.svg',
      'I can do\nboth',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _schedulePlaceholder = widget.profile.schedule;
    _languagesPlaceholder = widget.profile.languages.join(', ');
    _learningStylesPlaceholder = widget.profile.interests.join(', ');
    _role = widget.profile.role;
    _learningSkillIds = List.from(widget.profile.learningSkillIds);
    _teachingSkillIds = List.from(widget.profile.teachingSkillIds);

    if (widget.profile.avatarUrl != null) {
      _photos[0] = widget.profile.avatarUrl;
    }
  }

  String _shortenDay(String day) {
    return day.length >= 3 ? day.substring(0, 3) : day;
  }

  List<String> _sortDays(Iterable<String> days) {
    const dayOrder = {
      'Monday': 0,
      'Tuesday': 1,
      'Wednesday': 2,
      'Thursday': 3,
      'Friday': 4,
      'Saturday': 5,
      'Sunday': 6,
    };

    final sorted = days.toList();

    sorted.sort(
      (a, b) => (dayOrder[a] ?? 999).compareTo(dayOrder[b] ?? 999),
    );

    return sorted;
  }

  void _save() {
    final sortedSchedule = _sortDays(_schedule);

    final updated = widget.profile.copyWith(
      avatarUrl: _photos[0],
      schedule: sortedSchedule.isEmpty
          ? _schedulePlaceholder
          : sortedSchedule.join('/'),
      languages: _languages.isEmpty
          ? widget.profile.languages
          : _languages,
      interests: _learningStyles.isEmpty
          ? widget.profile.interests
          : _learningStyles,
      role: _role,
      learningSkillIds: _learningSkillIds,
      teachingSkillIds: _teachingSkillIds,
    );

    Navigator.pop(context, updated);
  }

  Future<void> _selectAvailability() async {
    final result = await showMultiSelectPicker(
      context: context,
      title: 'Availability',
      options: kDayOptions,
      selected: _schedule.toSet(),
    );

    if (result != null) {
      setState(() {
        _schedule = _sortDays(result);
      });
    }
  }

  Future<void> _selectLanguages() async {
    final result = await showMultiSelectPicker(
      context: context,
      title: 'Language Preference',
      options: kLanguageOptions,
      selected: _languages.toSet(),
    );

    if (result != null) {
      setState(() {
        _languages = result.toList();
      });
    }
  }

  Future<void> _selectLearningStyles() async {
    final result = await showMultiSelectPicker(
      context: context,
      title: 'Learning Style',
      options: kLearningStyleOptions,
      selected: _learningStyles.toSet(),
    );

    if (result != null) {
      setState(() {
        _learningStyles = result.toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final textTheme2 = Theme.of(context).colorScheme.surface;
    final lightColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: lightColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(
          color: textTheme2,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: textTheme,
            size: 16,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: textTheme,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
              ),
              onPressed: _save,
              child: Text(
                'Save',
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme2,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _PhotoPickerRow(
                photoPaths: _photos,
                onChanged: (updated) {
                  setState(() => _photos = updated);
                },
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DropdownInfoField(
                    icon: Icons.calendar_today_outlined,
                    label: 'Availability',
                    value: _schedule
                        .map(_shortenDay)
                        .join('/'),
                    hint: _schedulePlaceholder,
                    onTap: _selectAvailability,
                  ),
                  const SizedBox(height: 12),
                  _DropdownInfoField(
                    icon: Icons.translate,
                    label: 'Language',
                    value: _languages.join(', '),
                    hint: _languagesPlaceholder,
                    onTap: _selectLanguages,
                  ),
                  const SizedBox(height: 12),
                  _DropdownInfoField(
                    icon: Icons.psychology,
                    label: 'Learning Style',
                    value: _learningStyles.join(', '),
                    hint: _learningStylesPlaceholder,
                    onTap: _selectLearningStyles,
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
                  RoleCardGroup(
                    options: _roleOptions,
                    selected: _role,
                    isEditing: true,
                    onSelect: (role) {
                      setState(() => _role = role);
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_role == OnboardingRole.learn ||
                      _role == OnboardingRole.both) ...[
                    SkillsCard.toLearn(
                      isEditing: true,
                      initialSkillIds: _learningSkillIds,
                      onChanged: (updatedIds) {
                        setState(() => _learningSkillIds = updatedIds);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_role == OnboardingRole.teach ||
                      _role == OnboardingRole.both)
                    SkillsCard.toTeach(
                      isEditing: true,
                      initialSkillIds: _teachingSkillIds,
                      onChanged: (updatedIds) {
                        setState(() => _teachingSkillIds = updatedIds);
                      },
                      onAttachFile: (skillId) {
                        debugPrint('Attach file for $skillId');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
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

    return GestureDetector(
      onTap: _handleTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            widget.icon,
            size: 18,
            color: textColor,
          ),
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
                      color: showHint
                          ? textColor.withValues(alpha: 0.4)
                          : textColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
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
    );
  }
}

class _PhotoPickerRow extends StatelessWidget {
  final List<String?> photoPaths;
  final ValueChanged<List<String?>> onChanged;

  const _PhotoPickerRow({
    required this.photoPaths,
    required this.onChanged,
  });

  Future<void> _pickPhoto(int index) async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    final updated = List<String?>.from(photoPaths);
    updated[index] = picked.path;
    onChanged(updated);
  }

  void _removePhoto(int index) {
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
    final hasImage = path != null;

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: hasImage ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary,
                  width: 3,
                ),
                image: hasImage
                    ? DecorationImage(
                        image: FileImage(File(path!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasImage
                  ? null
                  : const Center(
                      child: Icon(
                        Icons.add,
                        size: 32,
                        color: Colors.black54,
                      ),
                    ),
            ),
            if (hasImage)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onRemove,
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
          ],
        ),
      ),
    );
  }
}