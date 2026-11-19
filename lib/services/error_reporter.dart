import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends uncaught Flutter/async errors to `report_client_error`.
///
/// The RPC is rate-limited and stores only the message, stack, platform, and
/// app version. It never includes message bodies or profile content.
class ErrorReporter {
  ErrorReporter._();

  static final ErrorReporter instance = ErrorReporter._();
  static const _maxReports = 20;
  static const _timeout = Duration(seconds: 8);

  int _reports = 0;
  final Set<String> _seen = {};
  String _version = '';

  Future<void> install() async {
    try {
      _version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      _version = '';
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true;
    };
  }

  void report(Object error, StackTrace? stack) {
    if (_reports >= _maxReports) return;
    final message = error.toString();
    if (message.trim().isEmpty || !_seen.add(message)) return;
    _reports++;
    unawaited(_send(message, stack?.toString() ?? ''));
  }

  Future<void> _send(String message, String stack) async {
    try {
      await Supabase.instance.client
          .rpc(
            'report_client_error',
            params: {
              'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
              'p_app_version': _version,
              'p_route': '',
              'p_message': message,
              'p_stack': stack,
            },
          )
          .timeout(_timeout);
    } catch (_) {
      // Reporting must never throw or recurse.
    }
  }
}
