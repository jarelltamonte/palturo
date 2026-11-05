import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/chats_page.dart' show SkillTag;
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/services/chat_privacy_service.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/connectivity_service.dart';
import 'package:palturo/services/draft_service.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/screen/utils/chat_time_formatter.dart';
import 'package:palturo/screen/chat_pending_message.dart';
import 'package:palturo/widgets/user_avatar.dart';
import 'package:palturo/widgets/app_skeleton.dart';
import 'package:palturo/widgets/chat_menu_row.dart';
import 'package:palturo/widgets/chat_mute_sheet.dart';
import 'package:palturo/widgets/chat_search_sheet.dart';
import 'package:palturo/widgets/typing_indicator.dart';
import 'package:palturo/utils/friendly_error.dart';
import 'package:palturo/utils/presence_label.dart';
import 'package:palturo/widgets/app_feedback.dart';

@visibleForTesting
bool typingPayloadMatchesPeer(
  Map<String, dynamic> payload, {
  required String? peerId,
  required bool peerEnabled,
}) {
  if (!peerEnabled || peerId == null || peerId.isEmpty) return false;
  return payload['user_id']?.toString() == peerId;
}

@visibleForTesting
int? unreadDividerIndex({required int length, required int unreadAtOpen}) {
  if (unreadAtOpen <= 0 || length == 0) return null;
  return (length - unreadAtOpen).clamp(0, length - 1);
}

class ChatRoom extends StatefulWidget {
  final String? connectionId;
  final String name;
  final ImageProvider? avatarImage;
  final String? skillName;
  final PersonRole? role;
  final Person? person;

  const ChatRoom({
    super.key,
    this.connectionId,
    required this.name,
    this.avatarImage,
    this.skillName,
    this.role,
    this.person,
  });

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loadingMessages = false;
  String? _loadError;
  StreamSubscription? _messageStream;
  final Set<String> _expandedTimestamps = {};
  bool _sendingMessage = false;
  bool _feedbackGateOpen = false;
  bool _feedbackRated = false;
  bool _feedbackCollapsed = false;
  final List<PendingChatMessage> _pending = [];
  int _pendingSequence = 0;
  Timer? _draftTimer;
  bool _isScrolledUp = false;
  int _newWhileScrolled = 0;
  int _unreadAtOpen = 0;
  int? _unreadDividerIndex;
  String? _highlightedMessageKey;
  Timer? _highlightTimer;
  RealtimeChannel? _presenceChannel;
  bool _peerOnlineFromChannel = false;
  bool _peerTyping = false;
  bool _typingActive = false;
  DateTime? _lastTypingSent;
  Timer? _peerTypingTimer;

  @override
  void initState() {
    super.initState();
    final connectionId = widget.connectionId;
    if (connectionId != null) {
      for (final conversation in ChatStateService.instance.conversations) {
        if (conversation.connectionId == connectionId) {
          _unreadAtOpen = conversation.unread;
          break;
        }
      }
      ChatStateService.instance.enterRoom(connectionId);
      final draft = DraftService.instance.draftFor(connectionId);
      if (draft != null) {
        _messageController.text = draft;
        _messageController.selection = TextSelection.collapsed(
          offset: draft.length,
        );
      }
    }
    _messageController.addListener(() {
      setState(() {});
      _queueDraftSave();
      _onComposerChanged();
    });
    _scrollController.addListener(_onScrollChanged);
    ConnectivityService.instance.addListener(_onConnectivityChanged);
    ChatPrivacyService.instance.addListener(_onPrivacyChanged);
    ChatStateService.instance.addListener(_onConversationChanged);
    _subscribePresenceChannel();
    _loadMessages();
    _subscribeRealtime();
    _refreshFeedbackStatus();
  }

  void _onConversationChanged() {
    if (!mounted) return;
    setState(() {});
    final channel = _presenceChannel;
    if (channel != null) {
      _refreshPeerOnline(channel);
    } else {
      final privacy = ChatPrivacyService.instance;
      if (privacy.loaded &&
          (privacy.presenceEnabled || privacy.typingEnabled)) {
        _subscribePresenceChannel();
      }
    }
  }

  void _refreshPeerOnline(RealtimeChannel channel) {
    final connectionId = widget.connectionId;
    if (connectionId == null) return;
    final peerId =
        ChatStateService.instance.conversationFor(connectionId)?.otherUserId;
    final peerOnline =
        peerId != null &&
        channel.presenceState().any(
          (state) => state.presences.any(
            (presence) => presence.payload['user_id']?.toString() == peerId,
          ),
        );
    if (mounted && peerOnline != _peerOnlineFromChannel) {
      setState(() => _peerOnlineFromChannel = peerOnline);
    }
  }

  void _onPrivacyChanged() {
    final service = ChatPrivacyService.instance;
    final enabled =
        service.loaded && (service.presenceEnabled || service.typingEnabled);
    if (enabled && _presenceChannel == null) {
      _subscribePresenceChannel();
    } else if (enabled && !service.presenceEnabled) {
      final channel = _presenceChannel;
      if (channel != null) {
        unawaited(channel.untrack());
      }
      if (_peerOnlineFromChannel && mounted) {
        setState(() => _peerOnlineFromChannel = false);
      }
    } else if (enabled && service.presenceEnabled) {
      final channel = _presenceChannel;
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (channel != null && uid != null) {
        unawaited(channel.track({'user_id': uid}));
      }
    } else if (!enabled) {
      final channel = _presenceChannel;
      _presenceChannel = null;
      if (channel != null) {
        unawaited(Supabase.instance.client.removeChannel(channel));
      }
      if (_peerOnlineFromChannel && mounted) {
        setState(() => _peerOnlineFromChannel = false);
      }
    }
  }

  void _subscribePresenceChannel() {
    final connectionId = widget.connectionId;
    if (connectionId == null || _presenceChannel != null) return;
    final privacy = ChatPrivacyService.instance;
    if (!privacy.loaded ||
        (!privacy.presenceEnabled && !privacy.typingEnabled)) {
      return;
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final channel = Supabase.instance.client.channel(
      'chat:$connectionId',
      opts: const RealtimeChannelConfig(self: true),
    );
    channel.onPresenceSync((_) => _refreshPeerOnline(channel));
    channel.onBroadcast(event: 'typing', callback: _onTypingPayload);
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        final privacy = ChatPrivacyService.instance;
        if (privacy.presenceEnabled) {
          unawaited(channel.track({'user_id': uid}));
        }
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.closed) {
        if (identical(_presenceChannel, channel)) {
          _presenceChannel = null;
          if (mounted && _peerOnlineFromChannel) {
            setState(() => _peerOnlineFromChannel = false);
          }
          unawaited(Supabase.instance.client.removeChannel(channel));
        }
      }
    });
    _presenceChannel = channel;
  }

  void _onComposerChanged() {
    final privacy = ChatPrivacyService.instance;
    if (!privacy.loaded || !privacy.typingEnabled) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      if (_typingActive) unawaited(_sendTyping(false));
      return;
    }
    final now = DateTime.now();
    if (_lastTypingSent != null &&
        now.difference(_lastTypingSent!) < const Duration(seconds: 2)) {
      return;
    }
    _lastTypingSent = now;
    unawaited(_sendTyping(true));
  }

  Future<void> _sendTyping(bool active) async {
    final channel = _presenceChannel;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (channel == null || uid == null) return;
    _typingActive = active;
    try {
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': uid, 'active': active},
      );
    } catch (_) {
      // Typing is best-effort.
    }
  }

  void _onTypingPayload(Map<String, dynamic> payload) {
    final connectionId = widget.connectionId;
    if (connectionId == null) return;
    final conversation = ChatStateService.instance.conversationFor(
      connectionId,
    );
    if (conversation == null || !conversation.otherTypingEnabled) return;
    if (!typingPayloadMatchesPeer(
      payload,
      peerId: conversation.otherUserId,
      peerEnabled: conversation.otherTypingEnabled,
    )) {
      return;
    }

    final active = payload['active'] == true;
    _peerTypingTimer?.cancel();
    if (!active) {
      if (mounted && _peerTyping) setState(() => _peerTyping = false);
      return;
    }
    if (mounted && !_peerTyping) setState(() => _peerTyping = true);
    _peerTypingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _peerTyping) setState(() => _peerTyping = false);
    });
  }

  bool get _showPeerTyping {
    if (!_peerTyping) return false;
    final connectionId = widget.connectionId;
    if (connectionId == null) return false;
    final conversation = ChatStateService.instance.conversationFor(
      connectionId,
    );
    return conversation?.otherTypingEnabled ?? false;
  }

  String? get _peerPresenceText {
    final connectionId = widget.connectionId;
    if (connectionId == null) return null;
    final conversation = ChatStateService.instance.conversationFor(
      connectionId,
    );
    if (conversation == null || !conversation.otherPresenceEnabled) return null;
    if (_peerOnlineFromChannel) return 'Online';
    return presenceLabel(
      conversation.otherLastSeenAt,
      enabled: conversation.otherPresenceEnabled,
    );
  }

  void _onConnectivityChanged() {
    if (!ConnectivityService.instance.online) return;
    unawaited(_retryAllFailed());
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 64;
  }

  void _onScrollChanged() {
    final atBottom = _isNearBottom;
    if (atBottom) {
      if (_isScrolledUp || _newWhileScrolled > 0) {
        setState(() {
          _isScrolledUp = false;
          _newWhileScrolled = 0;
        });
      }
    } else if (!_isScrolledUp) {
      setState(() => _isScrolledUp = true);
    }
  }

  Future<void> _refreshFeedbackStatus() async {
    final connectionId = widget.connectionId;
    if (connectionId == null) return;
    try {
      final status = await MatchApi.feedbackStatus(connectionId);
      if (!mounted) return;
      setState(() {
        _feedbackGateOpen = status.gateOpen;
        _feedbackRated = status.alreadyRated;
      });
    } catch (_) {
      // Feedback is optional; a failed probe must not affect the chat.
    }
  }

  @override
  void dispose() {
    if (widget.connectionId != null) {
      ChatStateService.instance.leaveRoom(widget.connectionId!);
    }
    _messageStream?.cancel();
    _draftTimer?.cancel();
    _highlightTimer?.cancel();
    _peerTypingTimer?.cancel();
    if (_typingActive) {
      unawaited(_sendTyping(false));
    }
    _scrollController.removeListener(_onScrollChanged);
    ConnectivityService.instance.removeListener(_onConnectivityChanged);
    ChatPrivacyService.instance.removeListener(_onPrivacyChanged);
    ChatStateService.instance.removeListener(_onConversationChanged);
    final presence = _presenceChannel;
    _presenceChannel = null;
    if (presence != null) {
      unawaited(Supabase.instance.client.removeChannel(presence));
    }
    final connectionId = widget.connectionId;
    if (connectionId != null &&
        Supabase.instance.client.auth.currentUser != null) {
      unawaited(
        DraftService.instance.saveDraft(connectionId, _messageController.text),
      );
    }
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  SupabaseClient get _client => Supabase.instance.client;

  void _queueDraftSave() {
    final connectionId = widget.connectionId;
    if (connectionId == null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(
        DraftService.instance.saveDraft(connectionId, _messageController.text),
      );
    });
  }

  Future<void> _loadMessages() async {
    if (widget.connectionId == null) return;
    setState(() {
      _loadingMessages = true;
      _loadError = null;
    });
    try {
      final msgs = await MatchApi.getMessages(widget.connectionId!);
      if (!mounted) return;
      setState(() {
        _messages = _sortMessages(msgs);
        _placeUnreadDivider(_messages.length);
        _loadingMessages = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMessages = false;
        // Realtime may already have delivered the thread; do not cover it
        // with an error from a slower REST call.
        if (_messages.isEmpty) {
          _loadError = friendlyError(
            e,
            fallback: "Couldn't load this conversation. Please try again.",
          );
        }
      });
    }
  }

  void _subscribeRealtime() {
    if (widget.connectionId == null) return;
    _messageStream = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('connection_id', widget.connectionId!)
        .listen((rows) {
          if (!mounted) return;
          final wasAtBottom = _isNearBottom;
          final previousCount = _messages.length;
          setState(() {
            _messages = _sortMessages(rows);
            _placeUnreadDivider(_messages.length);
            if (rows.isNotEmpty) _loadError = null;
          });
          if (wasAtBottom) {
            _scrollToBottom();
          } else if (rows.length > previousCount) {
            setState(() {
              _newWhileScrolled += rows.length - previousCount;
            });
          }
        });
  }

  List<Map<String, dynamic>> _sortMessages(List<Map<String, dynamic>> rows) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      final ta =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime(1900);
      final tb =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime(1900);
      final byTime = ta.compareTo(tb);
      if (byTime != 0) return byTime;
      // stable tie-breaker for equal timestamps
      return (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
    });
    return sorted;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _scrollToBottomAnimated() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _placeUnreadDivider(int length) {
    if (_unreadDividerIndex != null) return;
    _unreadDividerIndex = unreadDividerIndex(
      length: length,
      unreadAtOpen: _unreadAtOpen,
    );
  }

  String _messageKey(Map<String, dynamic> message) =>
      message['id']?.toString() ??
      '${message['created_at']}-${message['sender_id']}-${message['body']}';

  Future<void> _sendMessage() async {
    if (_sendingMessage) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    if (widget.connectionId == null) {
      showAppSnackBar(context, 'This chat is not ready yet.');
      return;
    }

    unawaited(Haptics.tap());
    final pending = PendingChatMessage(
      localId:
          'pending-${DateTime.now().microsecondsSinceEpoch}-${_pendingSequence++}',
      body: message,
      createdAt: DateTime.now(),
    );
    _messageController.clear();
    _typingActive = false;
    _draftTimer?.cancel();
    unawaited(DraftService.instance.clearDraft(widget.connectionId!));
    setState(() {
      _pending.add(pending);
      _sendingMessage = true;
    });
    _scrollToBottom();
    await _deliverPending(pending);
  }

  Future<void> _deliverPending(PendingChatMessage pending) async {
    final connectionId = widget.connectionId;
    if (connectionId == null) return;
    try {
      await MatchApi.sendMessage(connectionId, pending.body);
      if (!mounted) return;
      setState(() {
        _pending.removeWhere((item) => item.localId == pending.localId);
      });
      await _reloadMessagesSilently();
      unawaited(
        MatchApi.checkFeedbackGate(connectionId)
            .then((_) {
              if (mounted) _refreshFeedbackStatus();
            })
            .catchError((_) {}),
      );
    } catch (_) {
      if (!mounted) return;
      unawaited(Haptics.error());
      setState(() {
        final index = _pending.indexWhere(
          (item) => item.localId == pending.localId,
        );
        if (index != -1) {
          _pending[index] = _pending[index].copyWith(
            status: PendingMessageStatus.failed,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Future<void> _retryPending(PendingChatMessage pending) async {
    if (_sendingMessage) return;
    setState(() {
      final index = _pending.indexWhere(
        (item) => item.localId == pending.localId,
      );
      if (index != -1) {
        _pending[index] = _pending[index].copyWith(
          status: PendingMessageStatus.sending,
        );
      }
      _sendingMessage = true;
    });
    await _deliverPending(pending);
  }

  Future<void> _reloadMessagesSilently() async {
    final connectionId = widget.connectionId;
    if (connectionId == null) return;
    try {
      final msgs = await MatchApi.getMessages(connectionId);
      if (!mounted) return;
      setState(() {
        _messages = _sortMessages(msgs);
      });
    } catch (_) {
      // Realtime will reconcile; the optimistic bubble already cleared.
    }
  }

  Future<void> _retryAllFailed() async {
    if (_sendingMessage) return;
    final failed = _pending
        .where((item) => item.status == PendingMessageStatus.failed)
        .toList(growable: false);
    if (failed.isEmpty) return;
    for (final item in failed) {
      if (!mounted) return;
      final stillQueued = _pending.any(
        (entry) =>
            entry.localId == item.localId &&
            entry.status == PendingMessageStatus.failed,
      );
      if (!stillQueued) continue;
      await _retryPending(item);
      final failedAgain = _pending.any(
        (entry) =>
            entry.localId == item.localId &&
            entry.status == PendingMessageStatus.failed,
      );
      if (failedAgain) break;
    }
  }

  Future<void> _copyMessage(String body) async {
    if (body.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    unawaited(Haptics.selection());
    showAppSnackBar(context, 'Message copied');
  }

  void _highlightMessage(String key) {
    _highlightTimer?.cancel();
    setState(() => _highlightedMessageKey = key);
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _highlightedMessageKey = null);
    });
  }

  Future<void> _showSearch() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.elevatedSurface(context),
      builder:
          (sheetContext) => ChatSearchSheet(
            messages: List<Map<String, dynamic>>.unmodifiable(_messages),
            formatTime: _formatSearchTime,
          ),
    );
    if (selected == null || !mounted) return;
    final index = _messages.indexWhere(
      (message) => _messageKey(message) == _messageKey(selected),
    );
    _highlightMessage(_messageKey(selected));
    if (index != -1 && _scrollController.hasClients && _messages.length > 1) {
      final ratio = index / (_messages.length - 1);
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent * ratio,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatSearchTime(Map<String, dynamic> message) {
    final time = DateTime.tryParse(message['created_at']?.toString() ?? '');
    if (time == null) return '';
    return ChatTimeFormatter.formatChatListTime(time);
  }

  void _leaveChat(String message) {
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnackBar(context, message);
  }

  void _showPeerUnavailable() {
    if (!mounted) return;
    showAppSnackBar(context, 'This profile is unavailable right now.');
  }

  Future<void> _block() async {
    final target = widget.person?.id;
    if (target == null || !_uuidPattern.hasMatch(target)) {
      _showPeerUnavailable();
      return;
    }
    try {
      await MatchApi.blockUser(target);
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        friendlyError(
          e,
          fallback: 'Could not block this person. Please try again.',
        ),
      );
      return;
    }
    await ChatStateService.instance.loadConversations(showSpinner: false);
    _leaveChat('You blocked ${widget.name}');
  }

  Future<void> _report(String reason) async {
    final target = widget.person?.id;
    if (target == null || !_uuidPattern.hasMatch(target)) {
      _showPeerUnavailable();
      return;
    }
    try {
      await MatchApi.reportUser(target, reason);
      if (!mounted) return;
      showAppSuccess(context, 'Thanks for your report.');
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        friendlyError(
          e,
          fallback: 'Could not send this report. Please try again.',
        ),
      );
    }
  }

  void _showProfile() {
    final person = widget.person;
    if (person == null) return;
    showPersonProfileDialog(
      context,
      person,
      onUnmatch: null,
      onBlock: _block,
      onReport: (reason) => _report(reason),
    );
  }

  Future<void> _showFeedbackDialog() async {
    final connectionId = widget.connectionId;
    if (connectionId == null || (!_feedbackGateOpen && _messages.length < 15)) {
      showAppSnackBar(
        context,
        'Feedback unlocks after 15 messages in this chat.',
      );
      return;
    }
    if (!_feedbackCollapsed) {
      setState(() => _feedbackCollapsed = true);
    }

    var clarity = 5;
    var reliability = 5;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget ratingField({
              required String label,
              required int value,
              required ValueChanged<int?> onChanged,
            }) {
              final textColor = Theme.of(context).colorScheme.secondary;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.boldText.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i == 5 ? 0 : 6),
                            child: Semantics(
                              button: true,
                              selected: value == i,
                              label: '$label, $i out of 5',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onChanged(i),
                                child: AnimatedContainer(
                                  duration: AppMotion.micro,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color:
                                        value == i
                                            ? AppColors.primary
                                            : AppColors.mutedSurface(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          value == i
                                              ? AppColors.primary
                                              : AppColors.border(context),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$i',
                                    style: AppTextStyles.boldText.copyWith(
                                      color:
                                          value == i ? Colors.black : textColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Needs work',
                        style: AppTextStyles.regularText.copyWith(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        'Excellent',
                        style: AppTextStyles.regularText.copyWith(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Leave feedback'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rate your experience with ${widget.name}.',
                    style: AppTextStyles.regularText.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ratingField(
                    label: 'Clarity of instruction',
                    value: clarity,
                    onChanged:
                        (value) => setDialogState(() => clarity = value ?? 5),
                  ),
                  const SizedBox(height: 12),
                  ratingField(
                    label: 'Reliability',
                    value: reliability,
                    onChanged:
                        (value) =>
                            setDialogState(() => reliability = value ?? 5),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(this.context);
                    try {
                      await MatchApi.submitFeedback(
                        connectionId,
                        clarity: clarity,
                        reliability: reliability,
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (_) {
                      if (!mounted) return;
                      showAppErrorOn(
                        messenger,
                        'Couldn’t save feedback. Try again.',
                      );
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true || !mounted) return;
    showAppSuccess(context, 'Thanks for your feedback.');
    await _refreshFeedbackStatus();
  }

  Future<void> _handleMenuAction(String action) async {
    FocusScope.of(context).unfocus();

    if (action == 'feedback') {
      await _showFeedbackDialog();
      return;
    }

    if (action == 'profile') {
      _showProfile();
      return;
    }

    if (action == 'mute') {
      await _showMuteSheet();
      return;
    }

    if (action == 'unread') {
      await _markUnreadAndLeave();
      return;
    }

    if (action == 'search') {
      await _showSearch();
      return;
    }

    if (action == 'retry_failed') {
      await _retryAllFailed();
      return;
    }

    final peerId = widget.person?.id;
    if (peerId == null || !_uuidPattern.hasMatch(peerId)) {
      _showPeerUnavailable();
      return;
    }

    if (action == 'report') {
      final reason = await showReportReasonDialog(context, name: widget.name);
      if (reason == null) return;
      _report(reason);
    } else if (action == 'block') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Block',
        message:
            '${widget.name} won’t be able to find or message you, and will be removed from your Pals. You can unblock them anytime in Settings.',
        confirmLabel: 'Block',
      );
      if (!confirmed) return;
      _block();
    }
  }

  Future<void> _showMuteSheet() async {
    final connectionId = widget.connectionId;
    if (connectionId == null) return;
    await showChatMuteSheet(context, connectionId);
  }

  Future<void> _markUnreadAndLeave() async {
    final connectionId = widget.connectionId;
    if (connectionId == null) return;
    final saved = await ChatStateService.instance.setMarkedUnread(
      connectionId,
      true,
    );
    if (!mounted) return;
    if (!saved) {
      showAppError(
        context,
        "Couldn't mark this chat unread. Please try again.",
      );
      return;
    }
    unawaited(Haptics.selection());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    final keyboardIsOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final isTyping = _messageController.text.isNotEmpty;
    final hasMessages = _messages.isNotEmpty || _pending.isNotEmpty;

    final showProfileInAppBar =
        hasMessages || keyboardIsOpen || isTyping || _peerTyping;
    final presenceText = _peerPresenceText;
    final peerTyping = _showPeerTyping;
    final bgColor = AppColors.mutedSurface(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      appBar: AppBar(
        toolbarHeight:
            adaptiveHeight +
            (widget.skillName != null ? 8 : 0) +
            (presenceText != null || peerTyping ? 10 : 0),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
            ),
            if (showProfileInAppBar) ...[
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: _showProfile,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      UserAvatar(
                        name: widget.name,
                        image: widget.avatarImage,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.boldText.copyWith(
                                color: textTheme,
                              ),
                            ),
                            if (widget.skillName != null &&
                                widget.skillName!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SkillTag(
                                  skillName: widget.skillName!,
                                  role: widget.role,
                                ),
                              ),
                            ],
                            if (peerTyping) ...[
                              const SizedBox(height: 2),
                              TypingIndicator(name: widget.name),
                            ] else if (presenceText != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color:
                                          presenceText == 'Online'
                                              ? AppColors.primary
                                              : AppColors.mutedText(context),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      presenceText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.regularText.copyWith(
                                        color:
                                            presenceText == 'Online'
                                                ? AppColors.accentText(context)
                                                : AppColors.mutedText(context),
                                        fontSize: 10.5,
                                        fontWeight:
                                            presenceText == 'Online'
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Chat options',
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: AppColors.elevatedSurface(context),
              elevation: 6,
              offset: const Offset(0, 40),
              onSelected: _handleMenuAction,
              itemBuilder:
                  (context) => [
                    if (_feedbackGateOpen && !_feedbackRated)
                      PopupMenuItem<String>(
                        value: 'feedback',
                        child: _menuRow(
                          'Leave feedback',
                          Icons.star_outline,
                          color: AppColors.primary,
                        ),
                      ),
                    if (widget.person != null)
                      PopupMenuItem<String>(
                        value: 'profile',
                        child: _menuRow('View profile', Icons.person_outline),
                      ),
                    PopupMenuItem<String>(
                      value: 'mute',
                      child: _menuRow(
                        ChatStateService.instance.isMuted(
                              widget.connectionId ?? '',
                            )
                            ? 'Unmute notifications'
                            : 'Mute notifications',
                        ChatStateService.instance.isMuted(
                              widget.connectionId ?? '',
                            )
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'unread',
                      child: _menuRow(
                        'Mark as unread',
                        Icons.mark_chat_unread_outlined,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'search',
                      child: _menuRow('Search in chat', Icons.search),
                    ),
                    if (_pending.any(
                      (item) => item.status == PendingMessageStatus.failed,
                    ))
                      PopupMenuItem<String>(
                        value: 'retry_failed',
                        child: _menuRow('Retry failed messages', Icons.refresh),
                      ),
                    PopupMenuItem<String>(
                      value: 'report',
                      child: _menuRow(
                        'Report',
                        Icons.flag_outlined,
                        color: AppColors.dangerText(context),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'block',
                      child: _menuRow(
                        'Block',
                        Icons.block,
                        color: AppColors.dangerText(context),
                      ),
                    ),
                  ],
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.more_horiz, color: textTheme, size: 22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.connectionId != null &&
              !_loadingMessages &&
              _loadError == null)
            _buildFeedbackProgress(textTheme),
          Expanded(
            child:
                _loadingMessages
                    ? const ChatRoomMessageSkeleton()
                    : _loadError != null && _messages.isEmpty
                    ? _buildLoadError(textTheme)
                    : !hasMessages && !showProfileInAppBar
                    ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _showProfile,
                              child: UserAvatar(
                                name: widget.name,
                                image: widget.avatarImage,
                                size: 100,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.name,
                              style: AppTextStyles.boldText.copyWith(
                                color: textTheme,
                                fontSize: 18,
                              ),
                            ),
                            if (widget.skillName != null &&
                                widget.skillName!.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'You matched on',
                                style: AppTextStyles.regularText.copyWith(
                                  color: textTheme.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SkillTag(
                                skillName: widget.skillName!,
                                role: widget.role,
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    : Stack(
                      children: [
                        _buildMessageList(textTheme),
                        if (_isScrolledUp)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: _buildScrollToBottomFab(),
                          ),
                      ],
                    ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onTap: _scrollToBottom,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      style: AppTextStyles.regularText.copyWith(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: bgColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Send message',
                    onPressed: _sendingMessage ? null : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      minimumSize: const Size(48, 48),
                      maximumSize: const Size(58, 48),
                    ),
                    icon:
                        _sendingMessage
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                            : const Icon(Icons.send_rounded, size: 21),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackProgress(Color textTheme) {
    if (_feedbackRated) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Icon(
              Icons.verified_outlined,
              size: 15,
              color: AppColors.accentText(context),
            ),
            const SizedBox(width: 6),
            Text(
              'Feedback submitted. Thank you!',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final count = _messages.length.clamp(0, 15);
    final open = _feedbackGateOpen || count >= 15;

    if (!open || _feedbackCollapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: open ? _showFeedbackDialog : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    open ? Icons.star_outline : Icons.lock_clock,
                    size: 16,
                    color:
                        open
                            ? AppColors.accentText(context)
                            : AppColors.mutedText(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      open
                          ? 'Feedback is ready'
                          : 'Feedback unlocks at 15 messages - $count/15',
                      style: AppTextStyles.regularText.copyWith(
                        color:
                            open
                                ? AppColors.accentText(context)
                                : AppColors.mutedText(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (open)
                    Text(
                      'Leave feedback',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.accentText(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star_outline,
                  size: 17,
                  color: AppColors.accentText(context),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Feedback is unlocked',
                    style: AppTextStyles.boldText.copyWith(
                      color: textTheme,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  'Ready',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: count / 15,
                minHeight: 5,
                backgroundColor: AppColors.mutedSurface(context),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rate your exchange when you are ready.',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                fontSize: 11,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _feedbackCollapsed = true),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Hide', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: _showFeedbackDialog,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Leave feedback',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(Color textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError ?? 'Couldn’t load this conversation.',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadMessages,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.black, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(String label, IconData icon, {Color? color}) =>
      ChatMenuRow(label: label, icon: icon, color: color);

  Widget _buildUnreadDivider(Color textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.accentText(context).withValues(alpha: 0.5),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Unread messages',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.accentText(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: AppColors.accentText(context).withValues(alpha: 0.5),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomFab() {
    return Semantics(
      button: true,
      label:
          _newWhileScrolled > 0
              ? 'Scroll to latest, $_newWhileScrolled new'
              : 'Scroll to latest',
      child: Material(
        color: AppColors.elevatedSurface(context),
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            _scrollToBottomAnimated();
            setState(() {
              _isScrolledUp = false;
              _newWhileScrolled = 0;
            });
          },
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                if (_newWhileScrolled > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _newWhileScrolled > 99 ? '99+' : '$_newWhileScrolled',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(Color textTheme) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.dragDetails != null &&
            _feedbackGateOpen &&
            !_feedbackCollapsed) {
          setState(() => _feedbackCollapsed = true);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: _messages.length + _pending.length,
        itemBuilder: (context, i) {
          if (i >= _messages.length) {
            final pending = _pending[i - _messages.length];
            return PendingMessageBubble(
              message: pending,
              onRetry:
                  pending.status == PendingMessageStatus.failed &&
                          !_sendingMessage
                      ? () => _retryPending(pending)
                      : null,
            );
          }
          final msg = _messages[i];
          final mine = msg['sender_id'] == myId;
          final currTime = DateTime.tryParse(
            msg['created_at']?.toString() ?? '',
          );
          DateTime? prevTime;
          if (i > 0) {
            prevTime = DateTime.tryParse(
              _messages[i - 1]['created_at']?.toString() ?? '',
            );
          }

          final showHeader =
              currTime != null &&
              ChatTimeFormatter.shouldShowMessengerHeader(prevTime, currTime);
          final messageKey = _messageKey(msg);
          final isSelected = _expandedTimestamps.contains(messageKey);

          return Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (i == _unreadDividerIndex) _buildUnreadDivider(textTheme),
              if (showHeader)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      ChatTimeFormatter.formatMessengerHeader(currTime),
                      style: AppTextStyles.regularText.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textTheme.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_expandedTimestamps.contains(messageKey)) {
                      _expandedTimestamps.remove(messageKey);
                    } else {
                      _expandedTimestamps.add(messageKey);
                    }
                  });
                },
                onLongPress: () => _copyMessage((msg['body'] ?? '').toString()),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color:
                        mine
                            ? AppColors.primary.withValues(alpha: 0.9)
                            : Colors.grey.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        _highlightedMessageKey == messageKey
                            ? Border.all(
                              color: AppColors.accentText(context),
                              width: 2,
                            )
                            : null,
                  ),
                  child: Text(
                    (msg['body'] ?? '').toString(),
                    style: AppTextStyles.regularText.copyWith(
                      color: mine ? Colors.black : textTheme,
                    ),
                  ),
                ),
              ),
              if (isSelected && currTime != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 2,
                    bottom: 4,
                    left: 4,
                    right: 4,
                  ),
                  child: Text(
                    ChatTimeFormatter.formatTimeOnly(currTime),
                    style: AppTextStyles.regularText.copyWith(
                      fontSize: 11,
                      color: textTheme.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
