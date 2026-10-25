import 'package:flutter/services.dart';
import 'package:palturo/services/preferences_service.dart';

/// Haptic feedback that respects the user's Settings preference.
class Haptics {
  const Haptics._();

  static Future<void> selection() async {
    if (!PreferencesService.instance.vibrationEnabled) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> impact() async {
    if (!PreferencesService.instance.vibrationEnabled) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> success() async {
    if (!PreferencesService.instance.vibrationEnabled) return;
    await HapticFeedback.mediumImpact();
  }
}
