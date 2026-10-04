import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

bool get _isCupertino => defaultTargetPlatform == TargetPlatform.iOS;

Future<Set<String>?> showMultiSelectPicker({
  required BuildContext context,
  required String title,
  required List<String> options,
  required Set<String> selected,
}) async {
  final result =
      _isCupertino
          ? await Navigator.of(context).push<Set<String>>(
            CupertinoPageRoute(
              builder:
                  (context) => _CupertinoSelectPage(
                    title: title,
                    options: options,
                    initialSelected: selected,
                  ),
            ),
          )
          : await showModalBottomSheet<Set<String>>(
            context: context,
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

  return result;
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
            Flexible(
              child:
                  widget.multiSelect
                      ? ListView(
                        shrinkWrap: true,
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
                        child: ListView(
                          shrinkWrap: true,
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
              ? Checkbox.adaptive(
                value: selected,
                activeColor: AppColors.primary,
                onChanged: (_) => onTap(),
              )
              : Radio<String>(value: label, activeColor: AppColors.primary),
    );
  }
}

class _CupertinoSelectPage extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> initialSelected;

  const _CupertinoSelectPage({
    required this.title,
    required this.options,
    required this.initialSelected,
  });

  @override
  State<_CupertinoSelectPage> createState() => _CupertinoSelectPageState();
}

class _CupertinoSelectPageState extends State<_CupertinoSelectPage> {
  late final Set<String> _selected = {...widget.initialSelected};

  void _pop() {
    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _selected);
        }
      },
      child: CupertinoPageScaffold(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(widget.title),
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _pop,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(CupertinoIcons.back), Text('Back')],
                ),
              ),
            ),
            SliverSafeArea(
              top: false,
              sliver: SliverList.separated(
                itemCount: widget.options.length,
                separatorBuilder:
                    (context, index) => const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Divider(height: 1),
                    ),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final isSelected = _selected.contains(option);

                  return CupertinoListTile(
                    title: Text(option),
                    leading: SizedBox(
                      width: 24,
                      child:
                          isSelected
                              ? const Icon(
                                CupertinoIcons.check_mark,
                                color: AppColors.primary,
                                size: 20,
                              )
                              : null,
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selected.remove(option);
                        } else {
                          _selected.add(option);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
