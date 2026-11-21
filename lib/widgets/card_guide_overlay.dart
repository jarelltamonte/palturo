import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:palturo/models/card_guide.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// A light, Next-driven spotlight tour of the For You card.
///
/// The caller owns persistence: it marks the guide seen only after
/// [onFinished] completes.
class CardGuideOverlay extends StatefulWidget {
  const CardGuideOverlay({
    super.key,
    required this.keys,
    required this.onFinished,
    this.showShowcaseStep = false,
    this.onOpenProfile,
  });

  final CardGuideKeys keys;
  final Future<void> Function() onFinished;
  final bool showShowcaseStep;
  final VoidCallback? onOpenProfile;

  @override
  State<CardGuideOverlay> createState() => _CardGuideOverlayState();
}

class _CardGuideOverlayState extends State<CardGuideOverlay> {
  static const List<CardGuideStep> _allSteps = [
    CardGuideStep(
      target: CardGuideTarget.card,
      title: 'Your first card',
      body:
          'One person at a time. Everything you need to decide is right here.',
    ),
    CardGuideStep(
      target: CardGuideTarget.skill,
      title: 'What they bring',
      body:
          '“Wants to teach” means they can show you. “Wants to learn” means '
          'they are looking for a teacher.',
    ),
    CardGuideStep(
      target: CardGuideTarget.name,
      title: 'Who you are meeting',
      body: 'Start with the name. This is the person behind the card.',
    ),
    CardGuideStep(
      target: CardGuideTarget.note,
      title: 'The note',
      body: 'A little context, in their own words.',
    ),
    CardGuideStep(
      target: CardGuideTarget.language,
      title: 'Language',
      body: 'What you can speak together.',
    ),
    CardGuideStep(
      target: CardGuideTarget.learningStyle,
      title: 'Learning style',
      body: 'How they like to learn or teach.',
    ),
    CardGuideStep(
      target: CardGuideTarget.schedule,
      title: 'Schedule',
      body: 'When they are usually free.',
    ),
    CardGuideStep(
      target: CardGuideTarget.actions,
      title: 'Your move',
      body: 'Skip to keep browsing, or send a request when it feels right.',
    ),
  ];

  static const CardGuideStep _showcaseStep = CardGuideStep(
    target: null,
    showcaseStep: true,
    title: 'One more step for mentors',
    body:
        'Learners can only find you when your teaching skills have a '
        'showcase. Add a photo or short video in Profile when you are ready.',
  );

  List<CardGuideStep> get _all => [
    ..._allSteps,
    if (widget.showShowcaseStep) _showcaseStep,
  ];

  int _index = 0;
  bool _finishing = false;
  bool _openingProfile = false;

  @override
  void initState() {
    super.initState();
    // The host card and the guide can be built in the same frame. Rebuild once
    // after layout so every target key has a measured RenderBox.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Rect? _rectFor(CardGuideTarget? target) {
    if (target == null) return null;
    final context = widget.keys.forTarget(target)?.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  List<CardGuideStep> get _steps {
    final all = _all;
    final available = all
        .where((step) => step.target == null || _rectFor(step.target) != null)
        .toList(growable: false);
    if (available.isEmpty) return all.take(1).toList(growable: false);
    return available;
  }

  Future<void> _next() async {
    if (_finishing) return;
    final steps = _steps;
    if (_index < steps.length - 1) {
      setState(() => _index += 1);
      return;
    }
    _finishing = true;
    await widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final index = _index.clamp(0, steps.length - 1);
    final step = steps[index];
    final targetRect = _rectFor(step.target);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = reduceMotion ? Duration.zero : AppMotion.base;
    final maxWidth = math.min(380.0, size.width - 32);
    final maxHeight = math.min(320.0, size.height * 0.5);

    final double top;
    if (targetRect == null) {
      top = (size.height - maxHeight) / 2;
    } else if (targetRect.center.dy < size.height * 0.45) {
      top = targetRect.bottom + 16;
    } else {
      top = targetRect.top - maxHeight - 16;
    }
    final clampedTop =
        top
            .clamp(
              padding.top + 12,
              math.max(
                padding.top + 12,
                size.height - padding.bottom - maxHeight - 12,
              ),
            )
            .toDouble();

    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Card guide',
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    hole: targetRect,
                    borderColor: AppColors.primary,
                    scrimColor: Colors.black.withValues(alpha: 0.74),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: motion,
              curve: Curves.easeOutCubic,
              top: clampedTop,
              left: (size.width - maxWidth) / 2,
              width: maxWidth,
              child: _GuideTooltip(
                index: index,
                total: steps.length,
                step: step,
                maxHeight: maxHeight,
                onNext: _next,
                onShowcasePrimary:
                    step.showcaseStep
                        ? () async {
                          // A double tap must not finish twice and open two
                          // profiles. "Do Later" also starts finishing, so do
                          // not navigate after it.
                          if (_openingProfile || _finishing) return;
                          _openingProfile = true;
                          try {
                            await _next();
                            widget.onOpenProfile?.call();
                          } finally {
                            _openingProfile = false;
                          }
                        }
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideTooltip extends StatelessWidget {
  const _GuideTooltip({
    required this.index,
    required this.total,
    required this.step,
    required this.maxHeight,
    required this.onNext,
    this.onShowcasePrimary,
  });

  final int index;
  final int total;
  final CardGuideStep step;
  final double maxHeight;
  final VoidCallback onNext;
  final Future<void> Function()? onShowcasePrimary;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final muted = AppColors.mutedText(context);
    final accent = AppColors.accentText(context);
    final last = index == total - 1;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'QUICK TOUR',
                    style: AppTextStyles.boldText.copyWith(
                      color: accent,
                      fontSize: 9,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      '${index + 1} of $total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.regularText.copyWith(
                        color: muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (index + 1) / total,
                  minHeight: 3,
                  backgroundColor: AppColors.progressTrack(context),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                step.title,
                style: AppTextStyles.boldText.copyWith(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.body,
                style: AppTextStyles.regularText.copyWith(
                  color: muted,
                  fontSize: 12,
                  height: 1.42,
                ),
              ),
              const SizedBox(height: 10),
              if (step.showcaseStep) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        onShowcasePrimary == null
                            ? null
                            : () {
                              onShowcasePrimary!();
                            },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.black,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: Text(
                      'Go to Profile',
                      style: AppTextStyles.boldText.copyWith(
                        color: AppColors.black,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onNext,
                  child: Text(
                    'Do Later',
                    style: AppTextStyles.regularText.copyWith(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.black,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: Text(
                      last ? 'Start exploring' : 'Next',
                      style: AppTextStyles.boldText.copyWith(
                        color: AppColors.black,
                        fontSize: 13,
                      ),
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

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.hole,
    required this.scrimColor,
    required this.borderColor,
  });

  final Rect? hole;
  final Color scrimColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final holeRect = hole?.inflate(6).intersect(screen);
    final paint = Paint()..color = scrimColor;

    if (holeRect == null || holeRect.isEmpty) {
      canvas.drawRect(screen, paint);
      return;
    }

    // Draw four opaque regions around the cutout instead of subtracting paths.
    // Path.combine differs between renderers; this leaves the card genuinely
    // un-dimmed on web and mobile.
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, holeRect.top), paint);
    canvas.drawRect(
      Rect.fromLTRB(0, holeRect.bottom, size.width, size.height),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, holeRect.top, holeRect.left, holeRect.bottom),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(holeRect.right, holeRect.top, size.width, holeRect.bottom),
      paint,
    );

    final rounded = RRect.fromRectAndRadius(
      holeRect,
      const Radius.circular(22),
    );
    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.scrimColor != scrimColor ||
      oldDelegate.borderColor != borderColor;
}
