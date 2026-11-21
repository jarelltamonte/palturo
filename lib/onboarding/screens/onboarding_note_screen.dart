import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/widgets/top_labeled_field.dart';
import '../onboarding_models.dart';
import '../widgets/onboarding_scaffold.dart';

/// One mandatory note page per learner skill selected in onboarding.
class OnboardingNoteScreen extends StatefulWidget {
  const OnboardingNoteScreen({
    super.key,
    required this.skillLabel,
    required this.initialNote,
    required this.onChanged,
    required this.onContinue,
    required this.onBack,
    required this.progress,
    this.index = 0,
    this.total = 1,
  });

  final String skillLabel;
  final String initialNote;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progress;
  final int index;
  final int total;

  @override
  State<OnboardingNoteScreen> createState() => _OnboardingNoteScreenState();
}

class _OnboardingNoteScreenState extends State<OnboardingNoteScreen> {
  late final TextEditingController _controller;

  bool get _valid => _controller.text.trim().length >= kOnboardingNoteMinLength;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    widget.onChanged(_controller.text);
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final muted = AppColors.mutedText(context);
    final question =
        'Tell us more about what you want to learn about ${widget.skillLabel}';

    return OnboardingScaffold(
      title: question,
      subtitle:
          'This appears on your card and helps Pals start a real conversation.',
      stepLabel:
          widget.total > 1
              ? 'Note ${widget.index + 1} of ${widget.total}'
              : 'One note per skill',
      progress: widget.progress,
      showBackButton: true,
      onBack: widget.onBack,
      primaryLabel: 'Continue',
      onPrimaryPressed: _valid ? widget.onContinue : null,
      scrollBody: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Say what you want from this skill, what you already know, or how '
            'you like to learn. A sentence or two is enough.',
            style: AppTextStyles.regularText.copyWith(
              color: muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          TopLabeledField(
            label: 'What do you want to learn?',
            controller: _controller,
            maxLines: 5,
            maxLength: kOnboardingNoteMaxLength,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                _valid ? Icons.check_circle_outline : Icons.info_outline,
                size: 14,
                color: _valid ? AppColors.primary : muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _valid
                      ? 'Looks good. You can edit this later from Profile.'
                      : 'Add at least $kOnboardingNoteMinLength characters.',
                  style: AppTextStyles.regularText.copyWith(
                    color: _valid ? AppColors.accentText(context) : muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Notes are checked before they appear on your card. Keep them '
            'specific and kind.',
            style: AppTextStyles.regularText.copyWith(
              color: textColor.withValues(alpha: 0.65),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
