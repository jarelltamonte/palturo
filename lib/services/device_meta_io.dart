import 'dart:io';

Map<String, String?> readDeviceMeta() {
  return {
    'platform': Platform.operatingSystem,
    'os': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'browser': null,
  };
}
