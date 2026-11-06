import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/notification_service.dart';

/// Device connectivity plus a small recovery hook for live data.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _initialized = false;
  bool _online = true;

  bool get online => _online;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _setOnline(await _connectivity.checkConnectivity());
    } catch (_) {}
    _subscription = _connectivity.onConnectivityChanged.listen(_setOnline);
  }

  void _setOnline(List<ConnectivityResult> results) {
    final nowOnline = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (nowOnline == _online) return;
    final wasOnline = _online;
    _online = nowOnline;
    notifyListeners();
    if (nowOnline && !wasOnline) {
      unawaited(NotificationService.instance.refresh());
      unawaited(
        ChatStateService.instance.loadConversations(showSpinner: false),
      );
    }
  }

  @visibleForTesting
  void debugSetOnline(bool value) {
    if (value == _online) return;
    _online = value;
    notifyListeners();
  }

  void reset() {
    if (_online) return;
    _online = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
