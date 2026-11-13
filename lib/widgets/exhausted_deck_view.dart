import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// The end of the For You deck.
///
/// The previously swiped cards fly back into a slightly imperfect pile, the
/// front card fades in grayed out, and the next steps sit below it.
class ExhaustedDeckView extends StatefulWidget {
  const ExhaustedDeckView({
    super.key,
    required this.onExplore,
    required this.onViewAgain,
    required this.onUpdateProfile,
    this.onBrowse,
  });

  final VoidCallback onExplore;
  final VoidCallback onViewAgain;
  final VoidCallback? onBrowse;
  final VoidCallback onUpdateProfile;

  static const String note =
      'You have seen all the top matches, we will notify you if a new match is found.';

  @override
  State<ExhaustedDeckView> createState() => _ExhaustedDeckViewState();
}

class _CardPose {
  const _CardPose(this.dx, this.dy, this.angle, this.scale);

  final double dx;
  final double dy;
  final double angle;
  final double scale;
}

class _ExhaustedDeckViewState extends State<ExhaustedDeckView>
    with SingleTickerProviderStateMixin {
  static const List<_CardPose> _poses = [
    _CardPose(-24, 8, -0.11, 0.95),
    _CardPose(22, -6, 0.10, 0.96),
    _CardPose(-12, 14, -0.06, 0.97),
    _CardPose(14, 10, 0.05, 0.98),
    _CardPose(0, 0, -0.012, 1),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.deckReturn,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _progress(int index) {
    final start = index * 0.07;
    final end = (0.62 + index * 0.07).clamp(0.0, 1.0);
    final t = ((_controller.value - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth, 420.0);
        final stackWidth = maxWidth.clamp(240.0, 360.0).toDouble();
        final stackHeight = math.min(
          stackWidth * 1.02,
          math.max(230.0, constraints.maxHeight * 0.46),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: stackWidth,
                  height: stackHeight,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder:
                        (context, _) => Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            for (var i = 0; i < _poses.length - 1; i++)
                              _buildBackCard(
                                context,
                                i,
                                stackWidth,
                                stackHeight,
                              ),
                            _buildFrontCard(context, stackWidth, stackHeight),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                ..._buildActions(maxWidth),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackCard(
    BuildContext context,
    int index,
    double width,
    double height,
  ) {
    final pose = _poses[index];
    final progress = _progress(index);
    final fromX = (index.isEven ? -1.15 : 1.15) * width;
    final fromY = (0.9 + index * 0.04) * height;
    final fromAngle = index.isEven ? -0.5 : 0.5;
    final dx = lerpDouble(fromX, pose.dx, progress)!;
    final dy = lerpDouble(fromY, pose.dy, progress)!;
    final angle = lerpDouble(fromAngle, pose.angle, progress)!;
    final scale = lerpDouble(0.9, pose.scale, progress)!;

    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: _BackCard(width: width * 0.68, height: height * 0.88),
          ),
        ),
      ),
    );
  }

  Widget _buildFrontCard(BuildContext context, double width, double height) {
    final pose = _poses.last;
    final progress = _progress(_poses.length - 1);
    final dx = lerpDouble(0, pose.dx, progress)!;
    final dy = lerpDouble(1.15 * height, pose.dy, progress)!;
    final angle = lerpDouble(0.18, pose.angle, progress)!;

    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.rotate(
          angle: angle,
          child: _FrontCard(width: width * 0.7, height: height * 0.9),
        ),
      ),
    );
  }

  List<Widget> _buildActions(double width) {
    return [
      SizedBox(
        width: width,
        child: FilledButton.icon(
          onPressed: widget.onExplore,
          icon: const Icon(Icons.travel_explore_rounded, size: 20),
          label: const Text('Explore'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.black,
            minimumSize: const Size.fromHeight(52),
            textStyle: AppTextStyles.boldText.copyWith(fontSize: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: width,
        child: OutlinedButton(
          onPressed: widget.onViewAgain,
          child: const Text('View Again'),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: width,
        child: OutlinedButton(
          onPressed: widget.onBrowse,
          child: const Text('Browse'),
        ),
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: widget.onUpdateProfile,
        child: const Text('Update Profile'),
      ),
    ];
  }
}

class _BackCard extends StatelessWidget {
  const _BackCard({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedSurface(context);
    final mutedText = AppColors.mutedText(context);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: muted,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 40,
                  color: mutedText.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: width * 0.62,
            height: 10,
            decoration: BoxDecoration(
              color: muted,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: width * 0.42,
            height: 8,
            decoration: BoxDecoration(
              color: muted,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrontCard extends StatelessWidget {
  const _FrontCard({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final muted = AppColors.mutedSurface(context);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [muted, AppColors.elevatedSurface(context)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: width - 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 28,
                    color: AppColors.mutedText(context),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  ExhaustedDeckView.note,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.regularText.copyWith(
                    color: textColor.withValues(alpha: 0.78),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
