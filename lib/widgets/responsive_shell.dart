import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';

/// Keeps the mobile-first app in a readable phone-width column when the web or
/// tablet surface is wider than the design supports.
class ResponsiveShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveShell({super.key, required this.child, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Keep native phones full-bleed in landscape too; tablets and desktop
    // surfaces have a shortest side above 600.
    if (media.size.width <= 600 || media.size.shortestSide <= 600) {
      return child;
    }

    return ColoredBox(
      color: AppColors.mutedSurface(context),
      child: Center(
        child: Container(
          width: maxWidth,
          height: media.size.height,
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(color: AppColors.border(context)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
