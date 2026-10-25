import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/services/match_api.dart';

/// Single source of truth for chat conversations, live preview/ordering,
/// and unread message indicators across navigation bar, chats page, and chat room.
class ChatStateService extends ChangeNotifier with WidgetsBindingObserver {
  static final ChatStateService instance = ChatStateService._();

  ChatStateService._();

  bool _initialized = false;
  List<ConversationLite> _conversations = [];
  bool _loading = false;
  String? _error;
  String? _activeConnectionId;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _midnightTimer;

  List<ConversationLite> get conversations => _conversations;
  bool get loading => _loading;
  String? get error => _error;
  String? get activeConnectionId => _activeConnectionId;
  AppLifecycleState get lifecycleState => _lifecycleState;

  /// Total unread count across all accepted conversations (excluding active chat room).
  int get totalUnreadCount {
    int total = 0;
    for (final c in _conversations) {
      if (c.connectionId != _activeConnectionId) {
        total += c.unread;
      }
    }
    return total;
  }

  /// Initialize singleton lifecycle observer and auth state listener once.
  void init() {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightTimer();

    // Listen to Supabase auth events
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        loadConversations();
        _subscribeRealtime();
      } else if (event == AuthChangeEvent.signedOut) {
        reset();
      }
    });

    if (Supabase.instance.client.auth.currentUser != null) {
      loadConversations();
      _subscribeRealtime();
    }
  }

  /// Loads conversations from backend and sorts them with most recent on top.
  Future<void> loadConversations({bool showSpinner = true}) async {
    if (showSpinner && _conversations.isEmpty) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final convos = await MatchApi.getConversations();
      final accepted = convos.where((c) => c.status == 'accepted').toList();
      _sortConversations(accepted);
      _conversations = accepted;
      _loading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  void _sortConversations(List<ConversationLite> list) {
    list.sort((a, b) {
      final ta = a.lastAt ?? DateTime(1900);
      final tb = b.lastAt ?? DateTime(1900);
      return tb.compareTo(ta); // newest first
    });
  }

  /// Subscribes once to Postgres changes on messages table.
  void _subscribeRealtime() {
    if (_realtimeChannel != null) return;
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    if (currentUser == null) return;

    _realtimeChannel =
        client
            .channel('chat_state_global_messages')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              callback: _handleRealtimeMessage,
            )
            .subscribe();
  }

  void _handleRealtimeMessage(PostgresChangePayload payload) {
    final eventType = payload.eventType;

    if (eventType == PostgresChangeEvent.insert) {
      final newRecord = payload.newRecord;
      final connectionId = newRecord['connection_id']?.toString();
      final senderId = newRecord['sender_id']?.toString();
      final body = newRecord['body']?.toString() ?? '';
      final createdAt =
          DateTime.tryParse(newRecord['created_at']?.toString() ?? '') ??
          DateTime.now();

      if (connectionId == null) return;

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final isMine = senderId == currentUserId;
      final isRoomActiveAndResumed =
          _activeConnectionId == connectionId &&
          _lifecycleState == AppLifecycleState.resumed;

      if (!isMine && isRoomActiveAndResumed) {
        // Active room viewing this chat right now -> mark read immediately
        MatchApi.markMessagesRead(connectionId);
      }

      final index = _conversations.indexWhere(
        (c) => c.connectionId == connectionId,
      );
      if (index != -1) {
        final old = _conversations[index];
        final newUnread =
            (isMine || isRoomActiveAndResumed) ? 0 : old.unread + 1;
        final updated = old.copyWith(
          lastMessage: body,
          lastAt: createdAt,
          unread: newUnread,
        );
        _conversations.removeAt(index);
        _conversations.insert(0, updated);
        notifyListeners();
      } else {
        // Conversation not found in local list (e.g. newly accepted connection) -> reload
        loadConversations(showSpinner: false);
      }
    } else if (eventType == PostgresChangeEvent.update) {
      final newRecord = payload.newRecord;
      final isRead = newRecord['is_read'] == true;
      final connectionId = newRecord['connection_id']?.toString();

      if (isRead && connectionId != null) {
        final index = _conversations.indexWhere(
          (c) => c.connectionId == connectionId,
        );
        if (index != -1 && _conversations[index].unread > 0) {
          final old = _conversations[index];
          _conversations[index] = old.copyWith(unread: 0);
          notifyListeners();
        }
      }
    }
  }

  /// Called when user opens ChatRoom. Clears unread immediately and marks read on server.
  Future<void> enterRoom(String connectionId) async {
    _activeConnectionId = connectionId;

    final index = _conversations.indexWhere(
      (c) => c.connectionId == connectionId,
    );
    if (index != -1 && _conversations[index].unread > 0) {
      final old = _conversations[index];
      _conversations[index] = old.copyWith(unread: 0);
      notifyListeners();
    }

    await MatchApi.markMessagesRead(connectionId);
  }

  /// Called when user leaves ChatRoom.
  void leaveRoom(String connectionId) {
    if (_activeConnectionId == connectionId) {
      _activeConnectionId = null;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      // Re-sync unread & conversations from backend
      if (_activeConnectionId != null) {
        MatchApi.markMessagesRead(_activeConnectionId!);
      }
      loadConversations(showSpinner: false);
      _scheduleMidnightTimer();
    }
  }

  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrowMidnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight =
        tomorrowMidnight.difference(now) + const Duration(seconds: 1);

    _midnightTimer = Timer(durationUntilMidnight, () {
      notifyListeners(); // Refresh relative date strings ("Today" -> "Yesterday")
      _scheduleMidnightTimer();
    });
  }

  /// Resets state on logout and unsubscribes from Realtime.
  void reset() {
    MatchApi.clearCaches();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    _conversations = [];
    _activeConnectionId = null;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        super.notifyListeners();
      });
    } else {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _midnightTimer?.cancel();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }
}
