import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../onboarding_models.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingInterestsScreen extends StatefulWidget {
  final String highlightWord;
  final List<OnboardingOption> options;
  final Set<String> selected;
  final int maxSelections;
  final ValueChanged<String> onToggle;
  final Future<OnboardingCreateResult> Function(String text)? onCreate;
  final double progress;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String stepLabel;

  const OnboardingInterestsScreen({
    super.key,
    required this.highlightWord,
    required this.options,
    required this.selected,
    required this.maxSelections,
    required this.onToggle,
    this.onCreate,
    required this.progress,
    required this.onContinue,
    this.onBack,
    this.onSkip,
    this.stepLabel = '',
  });

  @override
  State<OnboardingInterestsScreen> createState() =>
      _OnboardingInterestsScreenState();
}

class _OnboardingInterestsScreenState extends State<OnboardingInterestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _atLimit => widget.selected.length >= widget.maxSelections;

  bool get _canCreate =>
      _query.trim().isNotEmpty &&
      !_exactMatch &&
      !_atLimit &&
      widget.onCreate != null;

  bool get _exactMatch {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return false;
    return widget.options.any((option) => option.label.toLowerCase() == query);
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value.trim().toLowerCase();
      _error = null;
    });
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() {
      _query = '';
      _error = null;
    });
  }

  void _submit() {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;
    for (final option in widget.options) {
      if (option.label.toLowerCase() == text.toLowerCase()) {
        widget.onToggle(option.id);
        _clearQuery();
        return;
      }
    }
    _create();
  }

  Future<void> _create() async {
    final text = _searchController.text.trim();
    if (text.isEmpty || !_canCreate) return;
    final result = await showDialog<OnboardingCreateResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SkillCheckDialog(task: () => widget.onCreate!(text)),
    );
    if (!mounted || result == null) return;
    if (result.label == null) {
      setState(() => _error = result.message);
      return;
    }
    final label = result.label!;
    _searchController.text = label;
    _searchController.selection = TextSelection.collapsed(offset: label.length);
    setState(() {
      _error = null;
      // Keep the list focused on the checked skill instead of dropping back
      // to the full taxonomy.
      _query = label.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final query = _query.trim();
    final matching =
        query.isEmpty
            ? widget.options
            : widget.options
                .where((option) => option.label.toLowerCase().contains(query))
                .toList();
    final selectedNotMatching =
        widget.options
            .where(
              (option) =>
                  widget.selected.contains(option.id) &&
                  !matching.contains(option),
            )
            .toList();
    final selectedOptions =
        widget.options
            .where((option) => widget.selected.contains(option.id))
            .toList();
    final unselectedOptions =
        widget.options
            .where((option) => !widget.selected.contains(option.id))
            .toList();
    final visible =
        query.isEmpty
            ? [...selectedOptions, ...unselectedOptions]
            : [...selectedNotMatching, ...matching];

    return OnboardingScaffold(
      title: 'What are you interested in ${widget.highlightWord}',
      highlightWord: widget.highlightWord,
      highlightColor: AppColors.accentText(context),
      subtitle: 'Select up to ${widget.maxSelections}, or search for your own',
      progress: widget.progress,
      showBackButton: true,
      onBack: widget.onBack,
      onSkip: widget.onSkip,
      onPrimaryPressed: widget.selected.isNotEmpty ? widget.onContinue : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            cursorColor: AppColors.accentText(context),
            style: AppTextStyles.regularText.copyWith(
              color: textTheme,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'Search or add a skill',
              hintStyle: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.5),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: textTheme.withValues(alpha: 0.6),
              ),
              suffixIcon:
                  query.isEmpty
                      ? null
                      : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearQuery,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: textTheme.withValues(alpha: 0.6),
                        ),
                      ),
              filled: true,
              fillColor: AppColors.mutedSurface(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: AppColors.accentText(context),
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.dangerText(context),
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_canCreate)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _InterestChip(
                        label: 'Create "${_searchController.text.trim()}"',
                        icon: Icons.add_rounded,
                        selected: false,
                        dimmed: false,
                        onTap: _create,
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in visible)
                        _InterestChip(
                          label: option.label,
                          selected: widget.selected.contains(option.id),
                          dimmed:
                              _atLimit && !widget.selected.contains(option.id),
                          onTap: () => widget.onToggle(option.id),
                        ),
                    ],
                  ),
                  if (matching.isEmpty && !_canCreate)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _atLimit
                            ? 'Remove a skill to add another.'
                            : 'No skills match. Try another word.',
                        style: AppTextStyles.regularText.copyWith(
                          color: AppColors.mutedText(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs the moderation check while showing rotating skill facts, so a short
/// network wait does not feel like a stall.
class _SkillCheckDialog extends StatefulWidget {
  final Future<OnboardingCreateResult> Function() task;

  const _SkillCheckDialog({required this.task});

  @override
  State<_SkillCheckDialog> createState() => _SkillCheckDialogState();
}

class _SkillCheckDialogState extends State<_SkillCheckDialog> {
  static const _facts = <String>[
    'Filipino weavers passed patterns down through song, not written notes.',
    'Baybayin is an ancient Philippine script with three vowel sounds.',
    'Kakanin covers dozens of rice cakes, each tied to a region.',
    'Adobo takes its name from a Spanish marinade, but the technique is older.',
    'Parol lanterns began as bamboo frames lit by candles.',
    'Arnis trains sticks, blades, and empty hands together.',
    'Pinakbet comes from an Ilocano word for shriveled vegetables.',
    "T'nalak cloth is woven from abaca by the T'boli people.",
    'Burda embroidery once marked family status on clothing.',
    'The kudyapi is a two-stringed lute played across Mindanao.',
  ];

  Timer? _timer;
  int _fact = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _fact = (_fact + 1) % _facts.length);
    });
    _run();
  }

  Future<void> _run() async {
    OnboardingCreateResult result;
    try {
      result = await widget.task();
    } catch (_) {
      result = const OnboardingCreateResult.failed(
        'We could not check that skill right now. Please try again.',
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        backgroundColor: AppColors.elevatedSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.accentText(context),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Checking your skill',
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Making sure it lands in the right place.',
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.mutedText(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mutedSurface(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DID YOU KNOW?',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.mutedText(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _facts[_fact],
                        key: ValueKey(_fact),
                        style: AppTextStyles.regularText.copyWith(
                          color: textColor,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _InterestChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final fg = selected ? AppColors.textSecondary : secondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.5 : 1,
        child: Material(
          color: selected ? AppColors.primary : Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border(context),
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            splashFactory: NoSplash.splashFactory,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.regularText.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
