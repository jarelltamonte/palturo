import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palturo/onboarding/onboarding_flow.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/theme/app_colors.dart';

const kOtherId = 'other';
const kOtherPrefix = 'other:';
const kCustomSkillMaxLength = 30;

const kSkillCategories = <({String id, String label, IconData icon})>[
  (id: 'arts_design', label: 'Arts and Design', icon: Icons.palette_outlined),
  (
    id: 'language_culture',
    label: 'Language and Cultural Knowledge',
    icon: Icons.translate,
  ),
  (
    id: 'everyday_skills',
    label: 'Everyday Practical Skills',
    icon: Icons.handyman_outlined,
  ),
  (
    id: 'agriculture_livelihood',
    label: 'Agriculture and Livelihood',
    icon: Icons.agriculture_outlined,
  ),
];

const _kSmallWords = <String>{
  'ng',
  'sa',
  'na',
  'at',
  'ang',
  'mga',
  'ay',
  'o',
  'kay',
  'ni',
  'of',
  'and',
  'the',
  'in',
};

class CustomSkill {
  final String categoryId;
  final String text;

  const CustomSkill({this.categoryId = '', this.text = ''});

  bool get isValid => categoryId.isNotEmpty && text.trim().isNotEmpty;

  String encode() => '$kOtherPrefix$categoryId:${text.trim()}';

  static CustomSkill? tryParse(String id) {
    if (!id.startsWith(kOtherPrefix)) {
      final lower = id.trim().toLowerCase();
      if (lower == 'other' || lower == 'others') {
        return const CustomSkill();
      }
      return null;
    }
    final rest = id.substring(kOtherPrefix.length);
    final i = rest.indexOf(':');
    if (i < 0) return CustomSkill(text: rest);
    return CustomSkill(
      categoryId: rest.substring(0, i),
      text: rest.substring(i + 1),
    );
  }
}

bool isOtherOption(OnboardingOption o) {
  final id = o.id.trim().toLowerCase();
  final label = o.label.trim().toLowerCase();
  return id == 'other' ||
      id == 'others' ||
      label == 'other' ||
      label == 'others';
}

String toTitleCase(String input) {
  final words = input.split(' ');
  var seenFirstWord = false;
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (w.isEmpty) continue;
    final lower = w.toLowerCase();
    if (seenFirstWord && _kSmallWords.contains(lower)) {
      words[i] = lower;
    } else {
      words[i] = w[0].toUpperCase() + w.substring(1);
    }
    seenFirstWord = true;
  }
  return words.join(' ');
}

class TitleCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: toTitleCase(newValue.text));
  }
}

bool isSkillIdValid(String id) {
  final lower = id.trim().toLowerCase();
  if (lower == 'other' || lower == 'others') return false;
  return CustomSkill.tryParse(id)?.isValid ?? true;
}

class SkillsCard extends StatefulWidget {
  final bool isEditing;
  final String labelSuffix;
  final List<OnboardingOption> options;
  final int maxSkills;
  final List<String> initialSkillIds;
  final bool showAttachFile;
  final Map<String, String>? attachments;
  final ValueChanged<List<String>>? onChanged;
  final ValueChanged<String>? onAttachFile;
  final ValueChanged<String>? onRemoveAttachment;

  const SkillsCard({
    super.key,
    required this.isEditing,
    required this.labelSuffix,
    required this.options,
    required this.maxSkills,
    this.initialSkillIds = const [],
    this.showAttachFile = false,
    this.attachments,
    this.onChanged,
    this.onAttachFile,
    this.onRemoveAttachment,
  });

  factory SkillsCard.toLearn({
    Key? key,
    required bool isEditing,
    List<String> initialSkillIds = const [],
    ValueChanged<List<String>>? onChanged,
  }) {
    return SkillsCard(
      key: key,
      isEditing: isEditing,
      labelSuffix: 'Learn',
      options: kLearningOptions,
      maxSkills: 3,
      initialSkillIds: initialSkillIds,
      showAttachFile: false,
      onChanged: onChanged,
    );
  }

  factory SkillsCard.toTeach({
    Key? key,
    required bool isEditing,
    List<String> initialSkillIds = const [],
    Map<String, String>? attachments,
    ValueChanged<List<String>>? onChanged,
    ValueChanged<String>? onAttachFile,
    ValueChanged<String>? onRemoveAttachment,
  }) {
    return SkillsCard(
      key: key,
      isEditing: isEditing,
      labelSuffix: 'Teach',
      options: kTeachingOptions,
      maxSkills: 2,
      initialSkillIds: initialSkillIds,
      showAttachFile: true,
      attachments: attachments,
      onChanged: onChanged,
      onAttachFile: onAttachFile,
      onRemoveAttachment: onRemoveAttachment,
    );
  }

  @override
  State<SkillsCard> createState() => _SkillsCardState();
}

class _SkillsCardState extends State<SkillsCard> {
  late List<String> _skillIds;

  String? _resolveAttachmentPath(String skillId) {
    if (widget.attachments == null || widget.attachments!.isEmpty) return null;

    if (widget.attachments!.containsKey(skillId)) {
      return widget.attachments![skillId];
    }

    final matchOpt = widget.options.cast<OnboardingOption?>().firstWhere(
      (o) => o?.id == skillId,
      orElse: () => null,
    );
    if (matchOpt != null && widget.attachments!.containsKey(matchOpt.label)) {
      return widget.attachments![matchOpt.label];
    }

    final custom = CustomSkill.tryParse(skillId);
    if (custom != null && widget.attachments!.containsKey(custom.text)) {
      return widget.attachments![custom.text];
    }

    final normalized = skillId.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    for (final entry in widget.attachments!.entries) {
      if (entry.key.toLowerCase().replaceAll(RegExp(r'\s+'), '_') ==
          normalized) {
        return entry.value;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _skillIds = List.from(widget.initialSkillIds);
  }

  @override
  void didUpdateWidget(covariant SkillsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSkillIds != widget.initialSkillIds) {
      _skillIds = List.from(widget.initialSkillIds);
    }
  }

  void _addSkill() {
    if (_skillIds.length >= widget.maxSkills) return;
    final remaining =
        widget.options
            .where((o) => !isOtherOption(o) && !_skillIds.contains(o.id))
            .toList();
    if (remaining.isEmpty) return;
    setState(() {
      _skillIds.add(remaining.first.id);
    });
    widget.onChanged?.call(_skillIds);
  }

  void _removeSkill(int index) {
    setState(() {
      _skillIds.removeAt(index);
    });
    widget.onChanged?.call(_skillIds);
  }

  void _updateSkill(int index, String newId) {
    setState(() {
      _skillIds[index] = newId;
    });
    widget.onChanged?.call(_skillIds);
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = AppColors.primary;
    final themeColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.secondary;
    final canAddMore = _skillIds.length < widget.maxSkills;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 16, color: textColor),
                  children: [
                    const TextSpan(text: 'Skills to '),
                    TextSpan(
                      text: widget.labelSuffix,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isEditing && canAddMore)
                GestureDetector(
                  onTap: _addSkill,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: textColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: themeColor, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < _skillIds.length; i++) ...[
            _SkillRow(
              key: ValueKey('skill_row_$i'),
              selectedId: _skillIds[i],
              alreadyUsedIds: _skillIds,
              isEditing: widget.isEditing,
              accentColor: accentColor,
              options: widget.options,
              showAttachFile: widget.showAttachFile,
              attachmentPath: _resolveAttachmentPath(_skillIds[i]),
              onChanged: (newId) => _updateSkill(i, newId),
              onRemove: () => _removeSkill(i),
              onAttachFile:
                  widget.onAttachFile == null
                      ? null
                      : () => widget.onAttachFile!(_skillIds[i]),
              onRemoveAttachment:
                  widget.onRemoveAttachment == null
                      ? null
                      : () => widget.onRemoveAttachment!(_skillIds[i]),
            ),
            if (i != _skillIds.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SkillRow extends StatefulWidget {
  final String selectedId;
  final List<String> alreadyUsedIds;
  final bool isEditing;
  final Color accentColor;
  final List<OnboardingOption> options;
  final bool showAttachFile;
  final String? attachmentPath;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onAttachFile;
  final VoidCallback? onRemoveAttachment;

  const _SkillRow({
    super.key,
    required this.selectedId,
    required this.alreadyUsedIds,
    required this.isEditing,
    required this.accentColor,
    required this.options,
    required this.showAttachFile,
    this.attachmentPath,
    required this.onChanged,
    required this.onRemove,
    this.onAttachFile,
    this.onRemoveAttachment,
  });

  @override
  State<_SkillRow> createState() => _SkillRowState();
}

class _SkillRowState extends State<_SkillRow> {
  late final TextEditingController _controller;

  String get _otherId {
    for (final o in widget.options) {
      if (isOtherOption(o)) return o.id;
    }
    return kOtherId;
  }

  CustomSkill? get _custom {
    final parsed = CustomSkill.tryParse(widget.selectedId);
    if (parsed != null) return parsed;
    final lower = widget.selectedId.trim().toLowerCase();
    if (lower == _otherId || lower == 'other' || lower == 'others') {
      return const CustomSkill();
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _custom?.text ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit({String? text, String? categoryId}) {
    final current = _custom ?? const CustomSkill();
    widget.onChanged(
      CustomSkill(
        categoryId: categoryId ?? current.categoryId,
        text: text ?? current.text,
      ).encode(),
    );
  }

  Widget _buildCustomSection({
    required CustomSkill custom,
    required Color textColor,
    required Color dim,
  }) {
    final needsCategory =
        custom.text.trim().isNotEmpty && custom.categoryId.isEmpty;
    final errorColor = Theme.of(context).colorScheme.error;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: color, width: width),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            enabled: widget.isEditing,
            maxLength: kCustomSkillMaxLength,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.done,
            inputFormatters: [TitleCaseFormatter()],
            onChanged: (t) => _emit(text: t),
            cursorColor: textColor,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.secondary,
              hintText: 'Name your skill (e.g. Pottery)',
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
              counterText: '',
              prefixIcon: Icon(Icons.edit_outlined, size: 18, color: dim),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '${custom.text.length}/$kCustomSkillMaxLength',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              border: border(Colors.transparent, 0),
              enabledBorder: border(Colors.transparent, 0),
              disabledBorder: border(Colors.transparent, 0),
              focusedBorder: border(AppColors.primary, 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Category',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in kSkillCategories)
                _CategoryChip(
                  label: c.label,
                  icon: c.icon,
                  selected: custom.categoryId == c.id,
                  enabled: widget.isEditing,
                  accentColor: widget.accentColor,
                  textColor: textColor,
                  onTap: () => _emit(categoryId: c.id),
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topLeft,
            child:
                needsCategory && widget.isEditing
                    ? Padding(
                      padding: const EdgeInsets.only(top: 8, left: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 14, color: errorColor),
                          const SizedBox(width: 6),
                          Text(
                            'Pick a category so others can find your skill',
                            style: TextStyle(fontSize: 12, color: errorColor),
                          ),
                        ],
                      ),
                    )
                    : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  String _getDisplayName(String path) {
    final cleanPath = path.split('?').first;
    String rawName = cleanPath.split('/').last;
    if (rawName.startsWith('scaled_')) {
      rawName = rawName.substring('scaled_'.length);
    }
    if (rawName.startsWith('image_picker_')) {
      rawName = rawName.substring('image_picker_'.length);
    }
    rawName = rawName.replaceAll(RegExp(r'_\d{10,}\.'), '.');
    return rawName;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final themeColor = Theme.of(context).colorScheme.surface;
    final dim = widget.isEditing ? textColor : textColor.withValues(alpha: 0.5);
    final custom = _custom;

    final availableOptions =
        widget.options
            .where(
              (o) =>
                  isOtherOption(o) ||
                  o.id == widget.selectedId ||
                  o.label == widget.selectedId ||
                  (!widget.alreadyUsedIds.contains(o.id) &&
                      !widget.alreadyUsedIds.contains(o.label)),
            )
            .toList();

    if (!availableOptions.any(isOtherOption)) {
      availableOptions.add(const OnboardingOption(kOtherId, 'Other'));
    }

    String dropdownValue;
    if (custom != null) {
      dropdownValue = _otherId;
    } else {
      final match = availableOptions.cast<OnboardingOption?>().firstWhere(
        (o) => o?.id == widget.selectedId || o?.label == widget.selectedId,
        orElse: () => null,
      );

      if (match != null) {
        dropdownValue = match.id;
      } else if (widget.selectedId.trim().isNotEmpty &&
          widget.selectedId != 'other' &&
          widget.selectedId != 'others') {
        availableOptions.insert(
          0,
          OnboardingOption(widget.selectedId, widget.selectedId),
        );
        dropdownValue = widget.selectedId;
      } else {
        dropdownValue = _otherId;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: dim, width: 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: dropdownValue,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    icon:
                        widget.isEditing
                            ? Icon(Icons.keyboard_arrow_down, color: dim)
                            : const SizedBox.shrink(),
                    dropdownColor: themeColor,
                    style: TextStyle(color: dim, fontSize: 16),
                    onChanged:
                        widget.isEditing
                            ? (newId) {
                              if (newId == null) return;
                              if (newId == _otherId) {
                                if (!widget.selectedId.startsWith(
                                  kOtherPrefix,
                                )) {
                                  widget.onChanged(
                                    const CustomSkill().encode(),
                                  );
                                }
                              } else {
                                _controller.clear();
                                widget.onChanged(newId);
                              }
                            }
                            : null,
                    items:
                        availableOptions
                            .map(
                              (o) => DropdownMenuItem(
                                value: o.id,
                                child: Text(o.label),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),
            ),
            if (widget.isEditing) ...[
              const SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                shape: CircleBorder(
                  side: BorderSide(color: textColor, width: 1.5),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onRemove,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.close, color: textColor, size: 20),
                  ),
                ),
              ),
            ],
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child:
              custom == null
                  ? const SizedBox(width: double.infinity)
                  : _buildCustomSection(
                    custom: custom,
                    textColor: textColor,
                    dim: dim,
                  ),
        ),
        if (widget.showAttachFile && widget.isEditing)
          Padding(
            padding: const EdgeInsets.only(top: 10.0, left: 4.0),
            child:
                widget.attachmentPath != null &&
                        widget.attachmentPath!.isNotEmpty
                    ? Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: widget.onAttachFile,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 170,
                                    ),
                                    child: Text(
                                      _getDisplayName(widget.attachmentPath!),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onRemoveAttachment,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : GestureDetector(
                      onTap: widget.onAttachFile,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_file,
                            size: 16,
                            color: widget.accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Attach a file',
                            style: TextStyle(
                              color: widget.accentColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? accentColor : textColor.withValues(alpha: 0.35);

    return Opacity(
      opacity: enabled || selected ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    selected ? Icons.check : icon,
                    key: ValueKey(selected),
                    size: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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