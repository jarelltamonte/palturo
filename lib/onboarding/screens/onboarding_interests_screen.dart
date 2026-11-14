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
  final ValueChanged<String>? onCreate;
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
    setState(() => _query = value.trim().toLowerCase());
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
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

  void _create() {
    final text = _searchController.text.trim();
    if (text.isEmpty || !_canCreate) return;
    widget.onCreate!(text);
    _clearQuery();
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
