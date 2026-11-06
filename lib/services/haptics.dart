import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:palturo/services/preferences_service.dart';

/// Named feedback intents so call sites describe meaning, not vibration
/// strength. All feedback honours the user's Vibration preference.
enum HapticIntent {
  selection,
  tap,
  toggle,
  impact,
  success,
  warning,
  error,
  match,
}

class Haptics {
  const Haptics._();

  static const Duration _gap = Duration(milliseconds: 50);
  static final Map<HapticIntent, DateTime> _last = {};

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> fire(HapticIntent intent, {bool force = false}) async {
    if (!_supported || !PreferencesService.instance.vibrationEnabled) return;

    final now = DateTime.now();
    final previous = _last[intent];
    if (!force && previous != null && now.difference(previous) < _gap) {
      return;
    }
    _last[intent] = now;

    switch (intent) {
      case HapticIntent.selection:
      case HapticIntent.toggle:
        await HapticFeedback.selectionClick();
      case HapticIntent.tap:
      case HapticIntent.impact:
        await HapticFeedback.lightImpact();
      case HapticIntent.success:
        await HapticFeedback.mediumImpact();
      case HapticIntent.warning:
        await HapticFeedback.heavyImpact();
      case HapticIntent.error:
        await HapticFeedback.vibrate();
      case HapticIntent.match:
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> selection() => fire(HapticIntent.selection);

  static Future<void> tap() => fire(HapticIntent.tap);

  static Future<void> impact() => fire(HapticIntent.impact);

  static Future<void> success() => fire(HapticIntent.success);

  static Future<void> warning() => fire(HapticIntent.warning);

  static Future<void> error() => fire(HapticIntent.error);

  static Future<void> match() => fire(HapticIntent.match);

  /// Used by Settings to demonstrate the current preference.
  static Future<void> preview() => fire(HapticIntent.success, force: true);

  @visibleForTesting
  static void resetThrottle() => _last.clear();
}
