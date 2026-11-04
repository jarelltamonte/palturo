import 'dart:async';

import 'package:flutter/material.dart';
import 'package:palturo/models/app_notification.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single source of truth for persistent notification events.
///
/// Realtime inserts are emitted immediately on [events]; the same service also
/// keeps the Activity list and unread badge in sync. Chat unread counts remain
/// in `ChatStateService` because they have room-level read semantics.
class NotificationService extends ChangeNotifier with WidgetsBindingObserver {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final StreamController<AppNotification> _events =
      StreamController<AppNotification>.broadcast();
  final Set<String> _seenIds = <String>{};

  List<AppNotification> _items = const [];
  int _unread = 0;
  bool _loading = false;
  bool _initialized = false;
  String? _error;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  List<AppNotification> get items => List.unmodifiable(_items);

  int get unread => _unread;

  bool get loading => _loading;

  String? get error => _error;

  Stream<AppNotification> get events => _events.stream;

  AppLifecycleState get lifecycleState => _lifecycleState;

  bool get isForeground => _lifecycleState == AppLifecycleState.resumed;

  void init() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.session == null) {
        reset();
        return;
      }
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        _subscribe();
        refresh(showSpinner: _items.isEmpty);
      }
    });

    if (Supabase.instance.client.auth.currentUser != null) {
      _subscribe();
      refresh(showSpinner: true);
    }
  }

  /// Reloads the list and unread count. Failure keeps the last known state.
  Future<void> refresh({bool showSpinner = false}) async {
    if (_loading) return;
    _loading = true;
    if (showSpinner) notifyListeners();
    try {
      final rows = await MatchApi.listNotifications(limit: 50);
      final parsed = rows.map(AppNotification.fromRow).toList(growable: false);
      final enabled = PreferencesService.instance.notificationsEnabled;
      final unread = enabled ? await MatchApi.unreadNotifications() : 0;
      _items = parsed;
      _unread = unread;
      _error = null;
      _seenIds.addAll(
        parsed.map((item) => item.id).where((id) => id.isNotEmpty),
      );
      _trimSeen();
      notifyListeners();
    } catch (error) {
      // Activity is optional; a transient failure must not erase the last
      // known list or block the shell.
      _error = error.toString();
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

  Future<void> markItemRead(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1 || !_items[index].isUnread) return;

    final now = DateTime.now().toUtc();
    final updated = List<AppNotification>.from(_items);
    updated[index] = updated[index].copyWith(readAt: now);
    _items = updated;
    if (_unread > 0) _unread--;
    notifyListeners();

    try {
      await MatchApi.markNotificationRead(id);
    } catch (_) {
      unawaited(refresh());
    }
  }

  Future<void> markAllRead() async {
    if (_items.every((item) => !item.isUnread)) return;
    final now = DateTime.now().toUtc();
    _items = _items
        .map((item) => item.isUnread ? item.copyWith(readAt: now) : item)
        .toList(growable: false);
    _unread = 0;
    notifyListeners();

    try {
      await MatchApi.markNotificationsRead();
    } catch (_) {
      unawaited(refresh());
    }
  }

  /// Backwards-compatible alias for the old ActivityService API.
  Future<void> markRead() => markAllRead();

  void notifyPreferenceChanged() {
    if (!PreferencesService.instance.notificationsEnabled) {
      _unread = 0;
    }
    notifyListeners();
    if (PreferencesService.instance.notificationsEnabled) {
      unawaited(refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      if (_channel == null) _subscribe();
      unawaited(refresh());
    }
  }

  void reset() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    _items = const [];
    _unread = 0;
    _seenIds.clear();
    notifyListeners();
  }

  void _subscribe() {
    if (_channel != null) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    _channel =
        client
            .channel('notifications:${user.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: user.id,
              ),
              callback: _handleInsert,
            )
            .subscribe();
  }

  void _handleInsert(PostgresChangePayload payload) {
    final record = payload.newRecord;
    if (record.isEmpty) return;
    final item = AppNotification.fromRow(record);
    if (item.id.isEmpty || _seenIds.contains(item.id)) return;
    _seenIds.add(item.id);
    _trimSeen();

    if (item.isUnread) _unread++;
    _items = [item, ..._items.where((existing) => existing.id != item.id)];
    notifyListeners();
    _events.add(item);
    unawaited(refresh());
  }

  void _trimSeen() {
    if (_seenIds.length <= 200) return;
    final keep = _seenIds
        .toList(growable: false)
        .sublist(_seenIds.length - 200);
    _seenIds
      ..clear()
      ..addAll(keep);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    final channel = _channel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    _events.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
