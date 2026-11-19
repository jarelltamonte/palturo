import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:palturo/services/app_navigator.dart';
import 'package:palturo/widgets/app_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_reload_stub.dart'
    if (dart.library.js_interop) 'update_reload_web.dart';

/// Detects a newly deployed web build and offers a one-tap reload.
///
/// `tool/deploy_web.ps1` stamps `build/web-merged/version.json` with a unique
/// `build` value. The first check stores it; a later change prompts the user.
class UpdateService with WidgetsBindingObserver {
  UpdateService._();

  static final UpdateService instance = UpdateService._();
  static const _versionKey = 'app_build_version';
  static const _requestTimeout = Duration(seconds: 8);

  bool _started = false;
  bool _checking = false;

  void start() {
    if (!kIsWeb || _started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // First run only records the current build; it must not prompt.
    unawaited(check(prompt: false));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(check());
    }
  }

  Future<void> check({bool prompt = true}) async {
    if (!kIsWeb || _checking) return;
    _checking = true;
    try {
      final uri = Uri.parse(
        '/version.json?ts=${DateTime.now().millisecondsSinceEpoch}',
      );
      final res = await http.get(uri).timeout(_requestTimeout);
      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return;
      final build =
          (decoded['build'] ?? decoded['version'] ?? '').toString().trim();
      if (build.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString(_versionKey);
      await prefs.setString(_versionKey, build);
      if (prompt && previous != null && previous != build) {
        _prompt();
      }
    } catch (_) {
      // An update check must never disturb the app.
    } finally {
      _checking = false;
    }
  }

  void _prompt() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    showAppSnackBar(
      context,
      'A new version of PalTuro is available.',
      actionLabel: 'Update',
      onAction: reloadApp,
      duration: const Duration(seconds: 12),
    );
  }
}
