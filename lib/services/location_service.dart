import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Captures a coarse location for the signed-in user at most once a day.
///
/// The Cloudflare Worker at `/geo` returns country, region, region code, city,
/// and timezone derived from the request IP. The IP is never returned or
/// stored. A failed capture is silent; analytics simply has less coverage.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();
  static const _lastSyncKey = 'location_sync_date';
  static const _endpoint = 'https://palturo.app/geo';

  bool _started = false;
  bool _busy = false;

  void start() {
    if (_started) return;
    _started = true;
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.session != null) {
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
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      if (prefs.getString(_lastSyncKey) == today) return;

      final response = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final country = _text(decoded['country']);
      if (country == null || country.length != 2) return;

      await Supabase.instance.client.rpc(
        'save_my_location',
        params: {
          'p_country_code': country.toUpperCase(),
          'p_region': _text(decoded['region']),
          'p_region_code': _text(decoded['regionCode']),
          'p_city': _text(decoded['city']),
          'p_timezone': _text(decoded['timezone']),
        },
      );
      await prefs.setString(_lastSyncKey, today);
    } catch (_) {
      // Location is best-effort analytics, never a blocker.
    } finally {
      _busy = false;
    }
  }

  static String? _text(dynamic value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
