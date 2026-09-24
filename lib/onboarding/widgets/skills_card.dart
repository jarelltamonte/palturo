import 'package:flutter/material.dart';
import 'package:palturo/onboarding/onboarding_flow.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/theme/app_colors.dart';

class SkillsCard extends StatefulWidget {
  final bool isEditing;
  final String labelSuffix; // e.g. 'Learn' or 'Teach'
  final List<OnboardingOption> options; // kLearningOptions or kTeachingOptions
  final int maxSkills;
  final List<String> initialSkillIds;
  final bool showAttachFile; // 💡 mentor-only feature
  final ValueChanged<List<String>>? onChanged;
  final ValueChanged<String>? onAttachFile; // called with the skill id

  const SkillsCard({
    super.key,
    required this.isEditing,
    required this.labelSuffix,
    required this.options,
    required this.maxSkills,
    this.initialSkillIds = const [],
    this.showAttachFile = false,
    this.onChanged,
    this.onAttachFile,
  });

  // 💡 Convenience constructors matching your two use cases
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
    ValueChanged<List<String>>? onChanged,
    ValueChanged<String>? onAttachFile,
  }) {
    return SkillsCard(
      key: key,
      isEditing: isEditing,
      labelSuffix: 'Teach',
      options: kTeachingOptions,
      maxSkills: 2,
      initialSkillIds: initialSkillIds,
      showAttachFile: true,
      onChanged: onChanged,
      onAttachFile: onAttachFile,
    );
  }

  @override
  State<SkillsCard> createState() => _SkillsCardState();
}

class _SkillsCardState extends State<SkillsCard> {
  late List<String> _skillIds;

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
        widget.options.where((o) => !_skillIds.contains(o.id)).toList();
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
            color: Colors.black.withValues(alpha: 0.05),
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
              selectedId: _skillIds[i],
              alreadyUsedIds: _skillIds,
              isEditing: widget.isEditing,
              accentColor: accentColor,
              options: widget.options,
              showAttachFile: widget.showAttachFile,
              onChanged: (newId) => _updateSkill(i, newId),
              onRemove: () => _removeSkill(i),
              onAttachFile: widget.onAttachFile == null
                  ? null
                  : () => widget.onAttachFile!(_skillIds[i]),
            ),
            if (i != _skillIds.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final String selectedId;
  final List<String> alreadyUsedIds;
  final bool isEditing;
  final Color accentColor;
  final List<OnboardingOption> options;
  final bool showAttachFile;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onAttachFile;

  const _SkillRow({
    required this.selectedId,
    required this.alreadyUsedIds,
    required this.isEditing,
    required this.accentColor,
    required this.options,
    required this.showAttachFile,
    required this.onChanged,
    required this.onRemove,
    this.onAttachFile,
  });

  @override
  Widget build(BuildContext context) {
    final availableOptions = options
        .where((o) => o.id == selectedId || !alreadyUsedIds.contains(o.id))
        .toList();
    final textColor = Theme.of(context).colorScheme.secondary;
    final themeColor = Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isEditing ? textColor : textColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedId,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: isEditing ? textColor : textColor.withValues(alpha: 0.5),
                    ),
                    dropdownColor: themeColor,
                    style: TextStyle(
                      color: isEditing ? textColor : textColor.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                    onChanged: isEditing
                        ? (newId) {
                            if (newId != null) onChanged(newId);
                          }
                        : null,
                    items: availableOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.id,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            if (isEditing) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: textColor, width: 1.5),
                  ),
                  child: Icon(Icons.close, color: textColor, size: 20),
                ),
              ),
            ],
          ],
        ),
        // 💡 Mentor-only "Attach a file" action, shown only while editing
        if (showAttachFile && isEditing)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 8.0),
            child: GestureDetector(
              onTap: onAttachFile,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attach_file, size: 16, color: accentColor),
                  const SizedBox(width: 4),
                  Text(
                    'Attach a file',
                    style: TextStyle(
                      color: accentColor,
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