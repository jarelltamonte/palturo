import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';

/// Shared avatar treatment for list rows, chat headers, and profile summaries.
///
/// Images keep their own crop; missing/broken images fall back to initials on
/// the same neutral surface everywhere.
class UserAvatar extends StatelessWidget {
  final String name;
  final ImageProvider? image;
  final double size;
  final double? height;
  final bool circular;
  final double borderRadius;

  const UserAvatar({
    super.key,
    required this.name,
    this.image,
    required this.size,
    this.height,
    this.circular = true,
    this.borderRadius = 12,
  });

  static String initialsFor(String name) {
    final parts =
        name
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final radius = circular ? size / 2 : borderRadius;
    final boxHeight = height ?? size;
    final fallback = ColoredBox(
      color: AppColors.mutedSurface(context),
      child: Center(
        child: Text(
          initialsFor(name),
          style: TextStyle(
            color: AppColors.mutedText(context),
            fontSize: (size < boxHeight ? size : boxHeight) * 0.32,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: boxHeight,
        child:
            image == null
                ? fallback
                : Stack(
                  fit: StackFit.expand,
                  children: [
                    fallback,
                    Image(
                      image: image!,
                      fit: BoxFit.cover,
                      frameBuilder: (
                        context,
                        child,
                        frame,
                        wasSynchronouslyLoaded,
                      ) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: AppMotion.image,
                          curve: Curves.easeOut,
                          child: child,
                        );
                      },
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ],
                ),
      ),
    );
  }
}
