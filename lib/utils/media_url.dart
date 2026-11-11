import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Validates and renders media URLs.
///
/// Only HTTPS URLs on the project's Supabase host are allowed. This prevents a
/// profile from making other users' devices fetch arbitrary hosts (including
/// loopback/LAN addresses) and keeps the render path aligned with the database
/// trigger in `20261107000400_media_url_trust.sql`.
class MediaUrl {
  static Uri? tryParse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;
    if (uri.hasPort && uri.port != 443) return null;
    if (!uri.path.startsWith('/storage/v1/')) return null;

    final projectHost = Uri.tryParse(kSupabaseUrl)?.host;
    if (projectHost == null || projectHost.isEmpty) return null;
    if (uri.host != projectHost) return null;
    return uri;
  }

  static bool isAllowedOrPath(String? raw) {
    if (raw == null || raw.trim().isEmpty) return true;
    final value = raw.trim();
    if (value.startsWith('//') ||
        RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:').hasMatch(value)) {
      return tryParse(value) != null;
    }
    return true;
  }

  static String? sanitize(String? raw) => tryParse(raw)?.toString();

  static ImageProvider? image(String? raw) {
    final uri = tryParse(raw);
    return uri == null ? null : NetworkImage(uri.toString());
  }
}
