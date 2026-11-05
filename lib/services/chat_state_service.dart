import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/models/incoming_message_event.dart';
import 'package:palturo/services/chat_privacy_service.dart';
import 'package:palturo/services/match_api.dart';

/// Single source of truth for chat conversations, live preview/ordering,
/// and unread message indicators across navigation bar, chats page, and chat room.
@visibleForTesting
bool isMuteActive(DateTime? mutedUntil, {DateTime? now}) {
  if (mutedUntil == null) return false;
  return mutedUntil.isAfter(now ?? DateTime.now());
}

class ChatStateService extends ChangeNotifier with WidgetsBindingObserver {
  static final ChatStateService instance = ChatStateService._();

  ChatStateService._();

  bool _initialized = false;
  bool _resubscribing = false;
  bool _realtimeSubscribed = false;
  List<ConversationLite> _conversations = [];
  bool _loading = false;
  bool _hasLoaded = false;
  String? _error;
  String? _activeConnectionId;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _midnightTimer;
  Timer? _resubscribeTimer;
  int _resubscribeAttempts = 0;
  DateTime? _lastHeartbeat;
  Timer? _refreshTimer;
  int _conversationGeneration = 0;
  final StreamController<IncomingMessageEvent> _messageEvents =
      StreamController<IncomingMessageEvent>.broadcast();

  List<ConversationLite> get conversations => _conversations;
  bool get loading => _loading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  String? get activeConnectionId => _activeConnectionId;
  AppLifecycleState get lifecycleState => _lifecycleState;

  /// Incoming messages for the global notification presenter. Only messages
  /// received outside the active room are emitted.
  Stream<IncomingMessageEvent> get messageEvents => _messageEvents.stream;

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
      if (event == AuthChangeEvent.signedIn) {
        unawaited(ChatPrivacyService.instance.load());
        loadConversations();
        _startRefreshTimer();
        unawaited(_resubscribeRealtime());
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        // Realtime pushes the refreshed token to joined channels. If the
        // channel never joined, recover here.
        _resubscribeAttempts = 0;
        if (!_realtimeSubscribed) unawaited(_resubscribeRealtime());
        loadConversations(showSpinner: false);
      } else if (event == AuthChangeEvent.signedOut) {
        reset();
      }
    });

    ChatPrivacyService.instance.addListener(_onPrivacyChanged);
    if (Supabase.instance.client.auth.currentUser != null) {
      unawaited(ChatPrivacyService.instance.loadIfNeeded());
      loadConversations();
      _heartbeat(force: true);
      _startRefreshTimer();
      unawaited(_prepareRealtime());
    }
  }

  /// Foreground heartbeat; throttled and skipped when the user opted out.
  void _onPrivacyChanged() {
    if (ChatPrivacyService.instance.loaded &&
        ChatPrivacyService.instance.presenceEnabled) {
      _heartbeat(force: true);
    }
  }

  /// Presence refresh is independent of the local broadcast opt-in: even a
  /// user who hides their own status still needs fresh peer status.
  void _startRefreshTimer() {
    if (Supabase.instance.client.auth.currentUser == null) return;
    if (_refreshTimer?.isActive ?? false) return;
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_lifecycleState != AppLifecycleState.resumed) return;
      _heartbeat(force: true);
      unawaited(loadConversations(showSpinner: false));
    });
  }

  void _heartbeat({bool force = false}) {
    if (!ChatPrivacyService.instance.loaded) return;
    if (!ChatPrivacyService.instance.presenceEnabled) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastHeartbeat != null &&
        now.difference(_lastHeartbeat!) < const Duration(seconds: 60)) {
      return;
    }
    _lastHeartbeat = now;
    unawaited(MatchApi.touchLastSeen());
  }

  ConversationLite? conversationFor(String connectionId) {
    for (final conversation in _conversations) {
      if (conversation.connectionId == connectionId) return conversation;
    }
    return null;
  }

  Future<void> _prepareRealtime() async {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null) return;
    if (session.isExpired) {
      try {
        await auth.refreshSession();
      } catch (_) {
        _realtimeSubscribed = false;
        return;
      }
    }
    _subscribeRealtime();
  }

  Future<void> _resubscribeRealtime() async {
    if (_resubscribing) return;
    _resubscribing = true;
    _realtimeSubscribed = false;
    try {
      final channel = _realtimeChannel;
      _realtimeChannel = null;
      if (channel != null) {
        await Supabase.instance.client.removeChannel(channel);
      }
      await _prepareRealtime();
    } finally {
      _resubscribing = false;
    }
  }

  void _scheduleRealtimeResubscribe() {
    if (_resubscribeTimer != null || _resubscribeAttempts >= 3) return;
    final seconds = 2 << _resubscribeAttempts;
    _resubscribeAttempts++;
    _resubscribeTimer = Timer(Duration(seconds: seconds), () {
      _resubscribeTimer = null;
      unawaited(_resubscribeRealtime());
    });
  }

  /// Loads conversations from backend and sorts them with most recent on top.
  Future<bool> loadConversations({bool showSpinner = true}) async {
    if (Supabase.instance.client.auth.currentUser == null) return false;
    final generation = _conversationGeneration;
    if (showSpinner && _conversations.isEmpty) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final convos = await MatchApi.getConversations();
      if (generation != _conversationGeneration) return false;
      final accepted = convos.where((c) => c.status == 'accepted').toList();
      _sortConversations(accepted);
      _conversations = accepted;
      _loading = false;
      _hasLoaded = true;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (generation != _conversationGeneration) return false;
      _loading = false;
      // Keep whatever is already on screen; the full error scaffold is only
      // for a first load with no data.
      if (_conversations.isEmpty) {
        _error = e.toString();
      }
      notifyListeners();
      return false;
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

    _realtimeSubscribed = false;
    _realtimeChannel = client
        .channel('chat_state_global_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: _handleRealtimeMessage,
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _realtimeSubscribed = true;
            _resubscribeAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.closed) {
            _realtimeSubscribed = false;
          }
          if (status == RealtimeSubscribeStatus.channelError &&
              (error?.toString().toLowerCase().contains('jwt') ?? false)) {
            _scheduleRealtimeResubscribe();
          }
        });
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
        if (!isMine && !isRoomActiveAndResumed) {
          _emitIncoming(updated, body, createdAt);
        }
      } else {
        // Conversation not found in local list (e.g. newly accepted connection)
        // -> reload, then emit if the message is still relevant.
        unawaited(
          _emitAfterReload(
            connectionId: connectionId,
            body: body,
            createdAt: createdAt,
            isMine: isMine,
            isRoomActiveAndResumed: isRoomActiveAndResumed,
          ),
        );
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

  Future<void> _emitAfterReload({
    required String connectionId,
    required String body,
    required DateTime createdAt,
    required bool isMine,
    required bool isRoomActiveAndResumed,
  }) async {
    await loadConversations(showSpinner: false);
    if (isMine || isRoomActiveAndResumed) return;
    final index = _conversations.indexWhere(
      (c) => c.connectionId == connectionId,
    );
    if (index == -1) return;
    _emitIncoming(_conversations[index], body, createdAt);
  }

  void _emitIncoming(
    ConversationLite conversation,
    String body,
    DateTime createdAt,
  ) {
    if (body.trim().isEmpty) return;
    _messageEvents.add(
      IncomingMessageEvent(
        connectionId: conversation.connectionId,
        peerUserId: conversation.otherUserId,
        senderName: conversation.otherName,
        body: body,
        createdAt: createdAt,
        avatarUrl: conversation.otherAvatar,
        skillName: conversation.otherSkill,
        role: conversation.otherRole,
      ),
    );
  }

  /// Called when user opens ChatRoom. Clears unread immediately and marks read on server.
  bool isMuted(String connectionId) {
    return isMuteActive(mutedUntilFor(connectionId));
  }

  DateTime? mutedUntilFor(String connectionId) {
    final index = _conversations.indexWhere(
      (c) => c.connectionId == connectionId,
    );
    return index == -1 ? null : _conversations[index].mutedUntil;
  }

  bool isMarkedUnread(String connectionId) {
    final index = _conversations.indexWhere(
      (c) => c.connectionId == connectionId,
    );
    return index == -1 ? false : _conversations[index].markedUnread;
  }

  Future<bool> setMuted(String connectionId, DateTime? until) async {
    final index = _conversations.indexWhere(
      (c) => c.connectionId == connectionId,
    );
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        mutedUntil: until,
        clearMutedUntil: until == null,
      );
      notifyListeners();
    }
    try {
      await MatchApi.setConnectionMute(connectionId, until);
      return true;
    } catch (_) {
      // Revert to the server truth on failure.
      await loadConversations(showSpinner: false);
      return false;
    }
  }

  Future<bool> setMarkedUnread(String connectionId, bool unread) async {
    final index = _conversations.indexWhere(
      (c) => c.connectionId == connectionId,
    );
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        markedUnread: unread,
      );
      notifyListeners();
    }
    try {
      await MatchApi.setConnectionUnread(connectionId, unread);
      return true;
    } catch (_) {
      await loadConversations(showSpinner: false);
      return false;
    }
  }

  Future<void> enterRoom(String connectionId) async {
    _activeConnectionId = connectionId;

    final index = _conversations.indexWhere(
      (c) => c.connectionId == connectionId,
    );
    if (index != -1) {
      final old = _conversations[index];
      if (old.unread > 0 || old.markedUnread) {
        _conversations[index] = old.copyWith(unread: 0, markedUnread: false);
        notifyListeners();
      }
      if (old.markedUnread) {
        unawaited(setMarkedUnread(connectionId, false));
      }
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
      _heartbeat();
      _startRefreshTimer();
      unawaited(ChatPrivacyService.instance.loadIfNeeded());
      // Re-sync unread & conversations from backend
      if (_activeConnectionId != null) {
        MatchApi.markMessagesRead(_activeConnectionId!);
      }
      final session = Supabase.instance.client.auth.currentSession;
      if (_realtimeChannel == null ||
          !_realtimeSubscribed ||
          (session?.isExpired ?? false)) {
        _resubscribeAttempts = 0;
        unawaited(_resubscribeRealtime());
      }
      loadConversations(showSpinner: false);
      _scheduleMidnightTimer();
    } else if (state == AppLifecycleState.paused) {
      _heartbeat(force: true);
      _refreshTimer?.cancel();
      _refreshTimer = null;
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
    _conversationGeneration++;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _resubscribeAttempts = 0;
    _realtimeSubscribed = false;
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    _conversations = [];
    _activeConnectionId = null;
    _loading = false;
    _hasLoaded = false;
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
    _resubscribeTimer?.cancel();
    _refreshTimer?.cancel();
    ChatPrivacyService.instance.removeListener(_onPrivacyChanged);
    _realtimeSubscribed = false;
    _messageEvents.close();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }
}
