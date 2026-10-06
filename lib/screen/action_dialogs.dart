import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

const List<String> kReportReasons = [
  'Harassment',
  'Bullying',
  'Inappropriate content',
  'Spam or fake profile',
  'Irrelevant',
  'Other',
];

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (dialogContext) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

Future<String?> showReportReasonDialog(
  BuildContext context, {
  required String name,
}) {
  return showAdaptiveDialog<String>(
    context: context,
    builder: (dialogContext) => _ReportReasonDialog(name: name),
  );
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final confirmColor = destructive ? Colors.red : AppColors.primary;

    final titleWidget = Center(
      child: Text(
        title,
        style: AppTextStyles.regularText.copyWith(
          color: textTheme,
          fontSize: 18,
        ),
      ),
    );

    final body = Text(
      message,
      textAlign: TextAlign.center,
      style: AppTextStyles.regularText.copyWith(
        color: textTheme,
        fontSize: 14,
      ),
    );

    if (isIOS) {
      return CupertinoAlertDialog(
        title: titleWidget,
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(color: Colors.transparent, child: body),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: AppTextStyles.regularText.copyWith(color: confirmColor),
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: titleWidget,
      content: SizedBox(width: double.maxFinite, child: body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: AppTextStyles.regularText.copyWith(color: textTheme),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive
              ? TextButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.12),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                )
              : null,
          child: Text(
            confirmLabel,
            style: AppTextStyles.regularText.copyWith(color: confirmColor),
          ),
        ),
      ],
    );
  }
}

class _ReportReasonDialog extends StatefulWidget {
  final String name;

  const _ReportReasonDialog({required this.name});

  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  final TextEditingController _detailsController = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _selected;
    if (reason == null) return;
    final details = _detailsController.text.trim();
    final result =
        reason == 'Other' && details.isNotEmpty ? 'Other: $details' : reason;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    final titleWidget = Center(
      child: Text(
        'Report',
        style: AppTextStyles.regularText.copyWith(
          color: textTheme,
          fontSize: 18,
        ),
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Why are you reporting ${widget.name}?',
            textAlign: TextAlign.center,
            style: AppTextStyles.regularText.copyWith(
              color: textTheme,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final reason in kReportReasons)
          _ReasonTile(
            label: reason,
            selected: _selected == reason,
            onTap: () => setState(() => _selected = reason),
          ),
        if (_selected == 'Other') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _detailsController,
            minLines: 2,
            maxLines: 3,
            maxLength: 200,
            keyboardType: TextInputType.multiline,
            style: AppTextStyles.regularText.copyWith(
              color: textTheme,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Tell us more (optional)',
              hintStyle: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.45),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: textTheme.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: textTheme.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final canSubmit = _selected != null;

    if (isIOS) {
      return CupertinoAlertDialog(
        title: titleWidget,
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(color: Colors.transparent, child: content),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
          ),
          CupertinoDialogAction(
            onPressed: canSubmit ? _submit : null,
            child: Text(
              'Report',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.primary.withValues(
                  alpha: canSubmit ? 1 : 0.4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      scrollable: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: titleWidget,
      content: SizedBox(width: double.maxFinite, child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.regularText.copyWith(color: textTheme),
          ),
        ),
        TextButton(
          onPressed: canSubmit ? _submit : null,
          child: Text(
            'Report',
            style: AppTextStyles.regularText.copyWith(
              color: AppColors.primary.withValues(
                alpha: canSubmit ? 1 : 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected
                    ? AppColors.primary
                    : textTheme.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme,
                    fontSize: 14,
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