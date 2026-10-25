import 'package:flutter/material.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/preferences_service.dart';

/// In-app activity badge source. Backend notifications are the canonical
/// source; chat unread counts stay in ChatStateService because they have their
/// own room-level read semantics.
class ActivityService extends ChangeNotifier with WidgetsBindingObserver {
  ActivityService._();

  static final ActivityService instance = ActivityService._();

  int _unread = 0;
  bool _loading = false;

  int get unread => _unread;
  bool get loading => _loading;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (!PreferencesService.instance.notificationsEnabled) {
      _unread = 0;
      notifyListeners();
      return;
    }
    if (_loading) return;
    _loading = true;
    try {
      final value = await MatchApi.unreadNotifications();
      if (value != _unread) {
        _unread = value;
        notifyListeners();
      }
    } catch (_) {
      // Activity badges are optional; a transient failure must not block the
      // app shell or erase the last known count.
    } finally {
      _loading = false;
    }
  }

  Future<void> markRead() async {
    if (_unread == 0) return;
    _unread = 0;
    notifyListeners();
    try {
      await MatchApi.markNotificationsRead();
    } catch (_) {
      // The server will reconcile on the next refresh.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
