import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class OnboardingScaffold extends StatelessWidget {
  final String title;
  final String? highlightWord;
  final String? subtitle;
  final Widget child;

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
    this.subtitle,
    required this.child,
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

    return Scaffold(
      backgroundColor: surface,
      appBar: (showBackButton || progress > 0)
          ? PreferredSize(
              preferredSize: const Size.fromHeight(32.0 + kToolbarHeight),
              child: Padding(
                padding: const EdgeInsets.only(top: 32.0),
                child: AppBar(
                  backgroundColor: surface,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  automaticallyImplyLeading: false,
                  titleSpacing: 24,
                  title: Row(
                    children: [
                      if (showBackButton)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: onBack ?? () => Navigator.maybePop(context),
                            child: Icon(Icons.arrow_back_ios_new,
                                size: 18, color: secondary),
                          ),
                        ),
                      if (progress > 0)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation(
                                    AppColors.primary),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Title(
                title: title,
                highlightWord: highlightWord,
                color: secondary,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 16),
                Text(
                  subtitle!,
                  style:
                      AppTextStyles.regularText.copyWith(color: secondary),
                ),
              ],
              const SizedBox(height: 24),
              Expanded(child: Center(child: child)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 24),
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
                    style: AppTextStyles.regularText
                        .copyWith(color: secondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String title;
  final String? highlightWord;
  final Color color;

  const _Title({required this.title, this.highlightWord, required this.color});

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
            style: style.copyWith(color: AppColors.primary),
          ),
          if (parts.length > 1) TextSpan(text: parts.sublist(1).join(highlightWord!)),
        ],
      ),
    );
  }
}
