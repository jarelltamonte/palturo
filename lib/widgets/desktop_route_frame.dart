import 'package:flutter/material.dart';

/// Centers pushed pages on desktop surfaces so conversations, forms, and lists
/// keep a readable line length instead of stretching across the whole window.
/// Phones and tablets are returned untouched.
class DesktopRouteFrame extends StatelessWidget {
  const DesktopRouteFrame({
    super.key,
    required this.child,
    this.maxWidth = 820,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 900) return child;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Applies [DesktopRouteFrame] to every pushed page on desktop platforms while
/// keeping the stock Material transition for that platform.
class DesktopPageTransitionsBuilder extends PageTransitionsBuilder {
  const DesktopPageTransitionsBuilder({
    this.base = const ZoomPageTransitionsBuilder(),
  });

  final PageTransitionsBuilder base;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The first route is the app shell itself and already manages its own
    // desktop width. Only pushed pages are framed.
    final page = route.isFirst ? child : DesktopRouteFrame(child: child);
    return base.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      page,
    );
  }
}
