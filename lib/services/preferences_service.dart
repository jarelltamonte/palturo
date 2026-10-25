import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  late SharedPreferencesAsync _prefs;

  PreferencesService._internal();

  static PreferencesService instance = PreferencesService._internal();

  /// Runtime copies so sound/haptic feedback can be gated without awaiting
  /// storage on every tap. Settings writes both the copy and the backing key.
  bool notificationsEnabled = true;
  bool soundEnabled = true;
  bool vibrationEnabled = true;

  Future<void> init() async {
    _prefs = SharedPreferencesAsync();
    try {
      notificationsEnabled =
          await _prefs.getBool('notifications_enabled') ?? true;
      soundEnabled = await _prefs.getBool('sound_enabled') ?? true;
      vibrationEnabled = await _prefs.getBool('vibration_enabled') ?? true;
    } catch (_) {
      // Defaults keep the app usable if the platform preference store is
      // unavailable (for example during a cold web boot).
    }
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    await setBool('notifications_enabled', value);
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    await setBool('sound_enabled', value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    vibrationEnabled = value;
    await setBool('vibration_enabled', value);
  }

  Future<bool?> getBool(String key) async {
    return await _prefs.getBool(key);
  }

  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    return await _prefs.getString(key);
  }
}
