import 'package:flutter/foundation.dart';

import 'device_meta_stub.dart'
    if (dart.library.io) 'device_meta_io.dart'
    if (dart.library.js_interop) 'device_meta_web.dart' as impl;

/// Platform, OS, and browser hints for device analytics.
///
/// The app platform is normalized to `web`, `android`, `ios`, `windows`,
/// `macos`, or `linux`. No hardware identifiers or advertising IDs are read.
Map<String, String?> readDeviceMeta() {
  final base = impl.readDeviceMeta();
  final platform = kIsWeb ? 'web' : (base['platform'] ?? 'unknown');
  return {
    'platform': platform,
    'os': base['os'],
    'os_version': base['os_version'],
    'browser': base['browser'],
  };
}
