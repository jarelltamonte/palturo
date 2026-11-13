import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';

/// Keeps tablet-sized surfaces in a readable column. Desktop surfaces get the
/// full window because the navigation shell manages its own content widths,
/// and phones stay full-bleed.
class ResponsiveShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveShell({super.key, required this.child, this.maxWidth = 600});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width >= 900 ||
        media.size.width <= 600 ||
        media.size.shortestSide <= 600) {
      return child;
    }

    return ColoredBox(
      color: AppColors.mutedSurface(context),
      child: Center(
        child: SizedBox(
          width: maxWidth,
          height: media.size.height,
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
