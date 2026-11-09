import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class OnboardingScaffold extends StatelessWidget {
  final String title;
  final String? highlightWord;
  final Color? highlightColor;
  final String? subtitle;
  final String? stepLabel;
  final Widget child;

  /// Lets the whole body (header + child) scroll instead of constraining the
  /// child to the leftover height. Use only when [child] has no scroll view of
  /// its own and should stay fully reachable on short or heavily scaled
  /// viewports. The role step opts in; steps with their own list do not.
  final bool scrollBody;

  final double progress;
  final bool showBackButton;
  final VoidCallback? onBack;

  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;

  final bool showSkip;
  final VoidCallback? onSkip;

  const OnboardingScaffold({
    super.key,
    required this.title,
    this.highlightWord,
    this.highlightColor,
    this.subtitle,
    this.stepLabel,
    required this.child,
    this.scrollBody = false,
    this.progress = 0,
    this.showBackButton = false,
    this.onBack,
    this.primaryLabel = 'Continue',
    this.onPrimaryPressed,
    this.showSkip = true,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final surface = Theme.of(context).colorScheme.surface;
    // Keep the back target at 48 even on iOS; the toolbar grows to fit it.
    final adaptiveHeight = AppSpacing.topBarHeight();

    const double backIconSize = 18;
    final double backInset =
        (AppSpacing.pageHorizontal -
                (AppSpacing.iconTarget - backIconSize) / 2)
            .clamp(0.0, double.infinity)
            .toDouble();

    return Scaffold(
      backgroundColor: surface,
      appBar:
          (showBackButton || progress > 0)
              ? PreferredSize(
                preferredSize: Size.fromHeight(adaptiveHeight),
                child: AppBar(
                  toolbarHeight: adaptiveHeight,
                  backgroundColor: surface,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  automaticallyImplyLeading: false,
                  titleSpacing: 0,
                  title: Padding(
                    padding: EdgeInsets.only(
                      left: showBackButton ? backInset : AppSpacing.pageHorizontal,
                      right: AppSpacing.pageHorizontal,
                    ),
                    child: Row(
                      children: [
                        if (showBackButton)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              tooltip: 'Back',
                              onPressed:
                                  onBack ?? () => Navigator.maybePop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: AppSpacing.iconTarget,
                                minHeight: AppSpacing.iconTarget,
                              ),
                              icon: Icon(
                                Icons.arrow_back_ios_new,
                                size: backIconSize,
                                color: secondary,
                              ),
                            ),
                          ),
                        if (progress > 0)
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
              : null,
      body: SafeArea(
        bottom: false,
        child:
            scrollBody
                ? _buildScrollableBody(context, secondary)
                : _buildFixedBody(context, secondary),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPrimaryPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.3,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: AppTextStyles.boldText,
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(primaryLabel),
                ),
              ),
              if (showSkip) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Do this later',
                    style: AppTextStyles.regularText.copyWith(color: secondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixedBody(BuildContext context, Color secondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        16,
        AppSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._header(context, secondary),
          Expanded(child: Center(child: child)),
        ],
      ),
    );
  }

  Widget _buildScrollableBody(BuildContext context, Color secondary) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            16,
            AppSpacing.pageHorizontal,
            0,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(_header(context, secondary)),
          ),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            // SliverFillRemaining skips building its child when the header
            // consumes the viewport at 200% text. Constraining to the paint
            // extent keeps the cards built and scrollable in that case.
            return SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.remainingPaintExtent,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    0,
                    AppSpacing.pageHorizontal,
                    16,
                  ),
                  child: Center(child: child),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _header(BuildContext context, Color secondary) {
    return [
      if (stepLabel != null && stepLabel!.isNotEmpty) ...[
        Semantics(
          header: true,
          label: stepLabel,
          excludeSemantics: true,
          child: Text(
            stepLabel!,
            style: AppTextStyles.regularText.copyWith(
              color: AppColors.mutedText(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
      _Title(
        title: title,
        highlightWord: highlightWord,
        highlightColor: highlightColor,
        color: secondary,
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 16),
        Text(
          subtitle!,
          style: AppTextStyles.regularText.copyWith(color: secondary),
        ),
      ],
      const SizedBox(height: 24),
    ];
  }
}

class _Title extends StatelessWidget {
  final String title;
  final String? highlightWord;
  final Color? highlightColor;
  final Color color;

  const _Title({
    required this.title,
    this.highlightWord,
    this.highlightColor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.headingText.copyWith(color: color);

    final strut = StrutStyle(
      fontSize: style.fontSize,
      height: style.height,
      fontFamily: style.fontFamily,
      forceStrutHeight: true,
    );

    if (highlightWord == null || !title.contains(highlightWord!)) {
      return Text(title, style: style, strutStyle: strut);
    }

    final parts = title.split(highlightWord!);
    return RichText(
      strutStyle: strut,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: parts.first),
          TextSpan(
            text: highlightWord,
            style: style.copyWith(
              color: highlightColor ?? AppColors.accentText(context),
            ),
          ),
          if (parts.length > 1)
            TextSpan(text: parts.sublist(1).join(highlightWord!)),
        ],
      ),
    );
  }
}