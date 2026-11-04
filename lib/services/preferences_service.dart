import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService extends ChangeNotifier {
  late SharedPreferencesAsync _prefs;

  PreferencesService._internal();

  static PreferencesService instance = PreferencesService._internal();

  /// Runtime copies so sound/haptic feedback can be gated without awaiting
  /// storage on every tap. Settings writes both the copy and the backing key.
  bool notificationsEnabled = true;
  bool soundEnabled = true;
  bool vibrationEnabled = true;

  bool messageNotificationsEnabled = true;
  bool requestNotificationsEnabled = true;
  bool activityNotificationsEnabled = true;
  bool messagePreviewsEnabled = true;

  bool quietHoursEnabled = false;
  int quietStartMinutes = 22 * 60;
  int quietEndMinutes = 7 * 60;
  bool notificationPermissionAsked = false;

  Future<void> init() async {
    _prefs = SharedPreferencesAsync();
    try {
      notificationsEnabled =
          await _prefs.getBool('notifications_enabled') ?? true;
      soundEnabled = await _prefs.getBool('sound_enabled') ?? true;
      vibrationEnabled = await _prefs.getBool('vibration_enabled') ?? true;
      messageNotificationsEnabled =
          await _prefs.getBool('message_notifications_enabled') ?? true;
      requestNotificationsEnabled =
          await _prefs.getBool('request_notifications_enabled') ?? true;
      activityNotificationsEnabled =
          await _prefs.getBool('activity_notifications_enabled') ?? true;
      messagePreviewsEnabled =
          await _prefs.getBool('message_previews_enabled') ?? true;
      quietHoursEnabled = await _prefs.getBool('quiet_hours_enabled') ?? false;
      quietStartMinutes = await _prefs.getInt('quiet_start_minutes') ?? 22 * 60;
      quietEndMinutes = await _prefs.getInt('quiet_end_minutes') ?? 7 * 60;
      notificationPermissionAsked =
          await _prefs.getBool('notification_permission_asked') ?? false;
    } catch (_) {
      // Defaults keep the app usable if the platform preference store is
      // unavailable (for example during a cold web boot).
    }
    notifyListeners();
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    await setBool('notifications_enabled', value);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    await setBool('sound_enabled', value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    vibrationEnabled = value;
    await setBool('vibration_enabled', value);
    notifyListeners();
  }

  Future<void> setMessageNotificationsEnabled(bool value) async {
    messageNotificationsEnabled = value;
    await setBool('message_notifications_enabled', value);
    notifyListeners();
  }

  Future<void> setRequestNotificationsEnabled(bool value) async {
    requestNotificationsEnabled = value;
    await setBool('request_notifications_enabled', value);
    notifyListeners();
  }

  Future<void> setActivityNotificationsEnabled(bool value) async {
    activityNotificationsEnabled = value;
    await setBool('activity_notifications_enabled', value);
    notifyListeners();
  }

  Future<void> setMessagePreviewsEnabled(bool value) async {
    messagePreviewsEnabled = value;
    await setBool('message_previews_enabled', value);
    notifyListeners();
  }

  Future<void> setQuietHoursEnabled(bool value) async {
    quietHoursEnabled = value;
    await setBool('quiet_hours_enabled', value);
    notifyListeners();
  }

  Future<void> setQuietWindow({
    required int startMinutes,
    required int endMinutes,
  }) async {
    quietStartMinutes = startMinutes.clamp(0, (24 * 60) - 1);
    quietEndMinutes = endMinutes.clamp(0, (24 * 60) - 1);
    await setInt('quiet_start_minutes', quietStartMinutes);
    await setInt('quiet_end_minutes', quietEndMinutes);
    notifyListeners();
  }

  Future<void> setNotificationPermissionAsked(bool value) async {
    notificationPermissionAsked = value;
    await setBool('notification_permission_asked', value);
    notifyListeners();
  }

  bool get isQuietHoursNow => isQuietHours(DateTime.now());

  /// Treats the window as overnight when start > end.
  bool isQuietHours(DateTime time) {
    if (!quietHoursEnabled) return false;
    if (quietStartMinutes == quietEndMinutes) return false;
    final minutes = time.hour * 60 + time.minute;
    if (quietStartMinutes < quietEndMinutes) {
      return minutes >= quietStartMinutes && minutes < quietEndMinutes;
    }
    return minutes >= quietStartMinutes || minutes < quietEndMinutes;
  }

  Future<bool?> getBool(String key) async {
    return await _prefs.getBool(key);
  }

  Future<int?> getInt(String key) async {
    return await _prefs.getInt(key);
  }

  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    return await _prefs.getString(key);
  }
}
