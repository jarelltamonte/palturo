import 'dart:async';
import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_meta.dart';

/// Records this app install for device/OS analytics.
///
/// A random local device id distinguishes multiple devices for the same user.
/// No hardware serial, advertising id, or IP address is read.
class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();
  static const _deviceKey = 'analytics_device_id';

  bool _started = false;
  bool _busy = false;

  void start() {
    if (_started) return;
    _started = true;
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.session == null) return;
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.initialSession) {
        unawaited(capture());
      }
    });
    if (Supabase.instance.client.auth.currentSession != null) {
      unawaited(capture());
    }
  }

  Future<void> capture() async {
    if (_busy) return;
    if (Supabase.instance.client.auth.currentSession == null) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString(_deviceKey);
      if (deviceId == null || deviceId.length < 8) {
        deviceId = _newDeviceId();
        await prefs.setString(_deviceKey, deviceId);
      }

      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        final build = info.buildNumber.trim();
        appVersion = build.isEmpty ? info.version : '${info.version}+$build';
        if (appVersion.isEmpty) appVersion = null;
      } catch (_) {
        appVersion = null;
      }

      final meta = readDeviceMeta();
      await Supabase.instance.client.rpc(
        'save_my_device',
        params: {
          'p_device_id': deviceId,
          'p_platform': meta['platform'],
          'p_os': meta['os'],
          'p_os_version': meta['os_version'],
          'p_browser': meta['browser'],
          'p_app_version': appVersion,
        },
      );
    } catch (_) {
      // Device analytics is best-effort and never blocks the app.
    } finally {
      _busy = false;
    }
  }

  String _newDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}
