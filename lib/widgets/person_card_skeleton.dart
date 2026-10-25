import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/widgets/app_skeleton.dart';

/// A quiet card-shaped placeholder for the cold People deck load.
class PersonCardSkeleton extends StatefulWidget {
  const PersonCardSkeleton({super.key});

  @override
  State<PersonCardSkeleton> createState() => _PersonCardSkeletonState();
}

class _PersonCardSkeletonState extends State<PersonCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 0.9,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) {
    return SkeletonBox(
      width: width,
      height: height,
      radius: height / 2,
      color: AppColors.white.withValues(alpha: 0.14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Loading recommendations',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: _opacity,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border(context)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3A3A3A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const Spacer(),
                _bar(132, 12),
                const SizedBox(height: 12),
                _bar(220, 24),
                const SizedBox(height: 12),
                _bar(176, 12),
                const SizedBox(height: 8),
                _bar(148, 12),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _bar(double.infinity, 44)),
                    const SizedBox(width: 12),
                    Expanded(child: _bar(double.infinity, 44)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
