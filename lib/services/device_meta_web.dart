import 'package:web/web.dart' as web;

Map<String, String?> readDeviceMeta() {
  final ua = web.window.navigator.userAgent;
  String os = 'Unknown';
  String? version;

  final android = RegExp(r'Android ([0-9.]+)').firstMatch(ua)?.group(1);
  final ios = RegExp(r'OS ([0-9_]+)').firstMatch(ua)?.group(1);
  final mac = RegExp(r'Mac OS X ([0-9_]+)').firstMatch(ua)?.group(1);
  final windows = RegExp(r'Windows NT ([0-9.]+)').firstMatch(ua)?.group(1);

  if (ua.contains('Windows')) {
    os = 'Windows';
    version = windows;
  } else if (ua.contains('Android')) {
    os = 'Android';
    version = android;
  } else if (ua.contains('iPhone') || ua.contains('iPad')) {
    os = 'iOS';
    version = ios?.replaceAll('_', '.');
  } else if (ua.contains('Macintosh') || ua.contains('Mac OS X')) {
    os = 'macOS';
    version = mac?.replaceAll('_', '.');
  } else if (ua.contains('Linux')) {
    os = 'Linux';
  }

  String? browser;
  if (ua.contains('Edg/')) {
    browser = 'Edge';
  } else if (ua.contains('Chrome/') || ua.contains('CriOS')) {
    browser = 'Chrome';
  } else if (ua.contains('Firefox/') || ua.contains('FxiOS')) {
    browser = 'Firefox';
  } else if (ua.contains('Safari/')) {
    browser = 'Safari';
  }

  return {
    'platform': 'web',
    'os': os,
    'os_version': version,
    'browser': browser,
  };
}
