import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

bool get _isCupertino =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

class AvailabilityRow extends StatelessWidget {
  final String day;
  final String timeRange;
  final List<String> dayOptions;
  final ValueChanged<String> onDayChanged;
  final VoidCallback onTimeTap;
  final VoidCallback onRemove;

  const AvailabilityRow({
    super.key,
    required this.day,
    required this.timeRange,
    required this.dayOptions,
    required this.onDayChanged,
    required this.onTimeTap,
    required this.onRemove,
  });

  Future<void> _pickDay(BuildContext context) async {
    final result = _isCupertino
        ? await _showCupertinoDayPicker(context)
        : await _showMaterialDaySheet(context);
    if (result != null) onDayChanged(result);
  }

  Future<String?> _showCupertinoDayPicker(BuildContext context) {
    var index = dayOptions.indexOf(day);
    if (index < 0) index = 0;
    var selected = dayOptions[index];

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 260,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Text('Day', style: TextStyle(fontWeight: FontWeight.w600)),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController:
                      FixedExtentScrollController(initialItem: index),
                  itemExtent: 36,
                  onSelectedItemChanged: (i) => selected = dayOptions[i],
                  children: [
                    for (final d in dayOptions) Center(child: Text(d)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showMaterialDaySheet(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final secondary = Theme.of(context).colorScheme.secondary;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Day',
                    style: AppTextStyles.boldText.copyWith(color: secondary)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final d in dayOptions)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(d,
                              style: AppTextStyles.regularText
                                  .copyWith(color: secondary)),
                          trailing: d == day
                              ? const Icon(Icons.check_rounded,
                                  color: AppColors.primary)
                              : null,
                          onTap: () => Navigator.pop(context, d),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () => _pickDay(context),
              child: _Pill(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        day,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.regularText
                            .copyWith(color: secondary),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: secondary.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: onTimeTap,
              child: _Pill(
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 16, color: secondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        timeRange,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.regularText
                            .copyWith(color: secondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.transparent,
              child: Icon(Icons.close_rounded,
                  color: secondary.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: secondary.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}