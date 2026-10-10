import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

Future<Set<String>?> showMultiSelectPicker({
  required BuildContext context,
  required String title,
  required List<String> options,
  required Set<String> selected,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder:
        (context) => _SelectSheet(
          title: title,
          options: options,
          initialSelected: selected,
          multiSelect: true,
        ),
  );
}

class OnboardingSelectField extends StatefulWidget {
  final String? label;
  final IconData? labelIcon;
  final String hint;
  final String displayValue;
  final List<String> options;
  final Set<String> selected;
  final bool multiSelect;
  final ValueChanged<Set<String>> onChanged;

  const OnboardingSelectField({
    super.key,
    this.label,
    this.labelIcon,
    required this.hint,
    required this.displayValue,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiSelect = false,
  });

  @override
  State<OnboardingSelectField> createState() => _OnboardingSelectFieldState();
}

class _OnboardingSelectFieldState extends State<OnboardingSelectField> {
  bool _isOpen = false;

  Future<void> _openPicker(BuildContext context) async {
    setState(() => _isOpen = true);

    final result =
        widget.multiSelect
            ? await showMultiSelectPicker(
              context: context,
              title: widget.label ?? widget.hint,
              options: widget.options,
              selected: widget.selected,
            )
            : await showModalBottomSheet<Set<String>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder:
                  (context) => _SelectSheet(
                    title: widget.label ?? widget.hint,
                    options: widget.options,
                    initialSelected: widget.selected,
                    multiSelect: false,
                  ),
            );

    if (mounted) {
      setState(() => _isOpen = false);
    }

    if (result != null) {
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Row(
            children: [
              if (widget.labelIcon != null) ...[
                Icon(widget.labelIcon, size: 18, color: secondary),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label!,
                style: AppTextStyles.regularText.copyWith(color: secondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: () => _openPicker(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.displayValue.isEmpty
                        ? widget.hint
                        : widget.displayValue,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.regularText.copyWith(
                      color:
                          widget.displayValue.isEmpty
                              ? secondary.withValues(alpha: 0.5)
                              : secondary,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: secondary.withValues(alpha: 0.7),
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

class _SelectSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> initialSelected;
  final bool multiSelect;

  const _SelectSheet({
    required this.title,
    required this.options,
    required this.initialSelected,
    required this.multiSelect,
  });

  @override
  State<_SelectSheet> createState() => _SelectSheetState();
}

class _SelectSheetState extends State<_SelectSheet> {
  late final Set<String> _selected = {...widget.initialSelected};

  void _selectOption(String option) {
    setState(() {
      _selected
        ..clear()
        ..add(option);
    });

    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: AppTextStyles.boldText.copyWith(color: secondary),
            ),
            const SizedBox(height: 12),
            widget.multiSelect
                ? Column(
                  children: [
                    for (final option in widget.options)
                      _OptionTile(
                        label: option,
                        selected: _selected.contains(option),
                        multiSelect: true,
                        onTap: () {
                          setState(() {
                            if (_selected.contains(option)) {
                              _selected.remove(option);
                            } else {
                              _selected.add(option);
                            }
                          });
                        },
                      ),
                  ],
                )
                : RadioGroup<String>(
                  groupValue: _selected.isEmpty ? null : _selected.first,
                  onChanged: (value) {
                    if (value != null) {
                      _selectOption(value);
                    }
                  },
                  child: Column(
                    children: [
                      for (final option in widget.options)
                        _OptionTile(
                          label: option,
                          selected: _selected.contains(option),
                          multiSelect: false,
                          onTap: () => _selectOption(option),
                        ),
                    ],
                  ),
                ),
            if (widget.multiSelect) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    'Apply',
                    style: AppTextStyles.boldText.copyWith(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.multiSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        label,
        style: AppTextStyles.regularText.copyWith(color: secondary),
      ),
      trailing:
          multiSelect
              ? Checkbox(
                value: selected,
                activeColor: AppColors.primary,
                checkColor: AppColors.textSecondary,
                onChanged: (_) => onTap(),
              )
              : Radio<String>(value: label, activeColor: AppColors.primary),
    );
  }
}