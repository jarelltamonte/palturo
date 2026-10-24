import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';

class FilterOption {
  final String label;
  final String value;

  const FilterOption(this.label, this.value);
}

class FilterSection {
  final String key;
  final String title;
  final List<FilterOption> options;
  final String defaultValue;

  const FilterSection({
    required this.key,
    required this.title,
    this.options = const [],
    this.defaultValue = 'all',
  });

  bool get isComingSoon => options.isEmpty;
}

class FilterBottomSheet extends StatefulWidget {
  final List<FilterSection> sections;
  final Map<String, String> selected;
  final ValueChanged<Map<String, String>> onApply;

  const FilterBottomSheet({
    super.key,
    required this.sections,
    required this.selected,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required List<FilterSection> sections,
    required Map<String, String> selected,
    required ValueChanged<Map<String, String>> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.elevatedSurface(context),
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => FilterBottomSheet(
            sections: sections,
            selected: selected,
            onApply: onApply,
          ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Map<String, String> _draft;

  @override
  void initState() {
    super.initState();
    _draft = {
      for (final s in widget.sections)
        s.key: widget.selected[s.key] ?? s.defaultValue,
    };
  }

  void _reset() {
    setState(() {
      _draft = {for (final s in widget.sections) s.key: s.defaultValue};
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final primaryColor = AppColors.primary;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filters',
                      style: AppTextStyles.boldText.copyWith(
                        color: textColor,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: Text(
                      'Reset',
                      style: AppTextStyles.regularText.copyWith(
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < widget.sections.length; i++) ...[
                if (i > 0) const SizedBox(height: 20),
                _buildSection(widget.sections[i], textColor, primaryColor),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    widget.onApply(Map<String, String>.from(_draft));
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Apply',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    FilterSection section,
    Color textColor,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(section.title, textColor),
        const SizedBox(height: 8),
        if (section.isComingSoon)
          Text(
            'Coming soon',
            style: AppTextStyles.regularText.copyWith(
              color: textColor.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in section.options)
                _filterChip(
                  option.label,
                  _draft[section.key] == option.value,
                  () => setState(() => _draft[section.key] = option.value),
                  textColor,
                  primaryColor,
                ),
            ],
          ),
      ],
    );
  }

  Widget _sectionLabel(String label, Color textColor) {
    return Text(
      label,
      style: AppTextStyles.regularText.copyWith(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _filterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    Color textColor,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.micro,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : textColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.regularText.copyWith(
            color: isSelected ? Colors.black : textColor,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
