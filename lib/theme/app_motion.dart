/// One motion scale for the app. Keep press feedback snappy and screen
/// transitions calm; do not add bespoke durations in individual widgets.
class AppMotion {
  /// Immediate tap acknowledgement (scale, tonal press).
  static const Duration press = Duration(milliseconds: 120);

  /// Small state changes: chips, toggles, compact rows.
  static const Duration micro = Duration(milliseconds: 160);

  /// Standard content transitions: captions, role controls, dots.
  static const Duration base = Duration(milliseconds: 200);

  /// Larger surfaces: progress, onboarding pages, screen-level swaps.
  static const Duration screen = Duration(milliseconds: 240);

  /// Card dismissal/swipe exits.
  static const Duration exit = Duration(milliseconds: 280);

  /// Restoring an undone action.
  static const Duration feedback = Duration(milliseconds: 350);

  /// Ambient skeleton pulse (not a transition).
  static const Duration shimmer = Duration(milliseconds: 1100);

  /// Network image fade-in.
  static const Duration image = Duration(milliseconds: 220);
}
