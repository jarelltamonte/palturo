import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class OnboardingSelectField extends StatelessWidget {
  final String? label;
  final String hint;
  final String displayValue;
  final List<String> options;
  final Set<String> selected;
  final bool multiSelect;
  final ValueChanged<Set<String>> onChanged;

  const OnboardingSelectField({
    super.key,
    this.label,
    required this.hint,
    required this.displayValue,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiSelect = false,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SelectSheet(
        title: label ?? hint,
        options: options,
        initialSelected: selected,
        multiSelect: multiSelect,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.regularText.copyWith(color: secondary),
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
                    displayValue.isEmpty ? hint : displayValue,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.regularText.copyWith(
                      color: displayValue.isEmpty
                          ? secondary.withValues(alpha: 0.5)
                          : secondary,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: secondary.withValues(alpha: 0.7)),
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
  late Set<String> _selected = {...widget.initialSelected};

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
            Text(widget.title,
                style: AppTextStyles.boldText.copyWith(color: secondary)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in widget.options)
                    _OptionTile(
                      label: option,
                      selected: _selected.contains(option),
                      multiSelect: widget.multiSelect,
                      onTap: () {
                        setState(() {
                          if (widget.multiSelect) {
                            _selected.contains(option)
                                ? _selected.remove(option)
                                : _selected.add(option);
                          } else {
                            _selected = {option};
                          }
                        });
                        if (!widget.multiSelect) {
                          Navigator.pop(context, _selected);
                        }
                      },
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
                  child: const Text('Apply'),
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
      title: Text(label,
          style: AppTextStyles.regularText.copyWith(color: secondary)),
      trailing: Icon(
        multiSelect
            ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
            : (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
        color: selected ? AppColors.primary : secondary.withValues(alpha: 0.4),
      ),
    );
  }
}
