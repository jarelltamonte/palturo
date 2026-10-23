import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/chats_page.dart' show SkillTag;
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/screen/utils/chat_time_formatter.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.connectionId != null) {
      ChatStateService.instance.enterRoom(widget.connectionId!);
    }
    _messageController.addListener(() {
      setState(() {});
    });
    _loadMessages();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    if (widget.connectionId != null) {
      ChatStateService.instance.leaveRoom(widget.connectionId!);
    }
    _messageStream?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  SupabaseClient get _client => Supabase.instance.client;

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
        _loadingMessages = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMessages = false;
        // Realtime may already have delivered the thread; do not cover it
        // with an error from a slower REST call.
        if (_messages.isEmpty) {
          _loadError =
              'Couldn’t load this conversation.\nPlease check your connection.';
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
          setState(() {
            _messages = _sortMessages(rows);
            if (rows.isNotEmpty) _loadError = null;
          });
          _scrollToBottom();
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

  Future<void> _sendMessage() async {
    if (_sendingMessage) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    if (widget.connectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This chat is not connected to the backend yet.'),
        ),
      );
      return;
    }

    setState(() => _sendingMessage = true);
    try {
      await MatchApi.sendMessage(widget.connectionId!, message);
      if (!mounted) return;
      // Keep anything the user typed while the request was in flight.
      if (_messageController.text.trim() == message) {
        _messageController.clear();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  void _leaveChat(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPeerUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This profile is unavailable right now.')),
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Block failed: $e')));
      return;
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thanks for your report.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report failed: $e')));
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

  Future<void> _handleMenuAction(String action) async {
    FocusScope.of(context).unfocus();

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
            '${widget.name} won’t be able to find or message you, and will be removed from your matches. You can unblock them anytime in Settings.',
        confirmLabel: 'Block',
      );
      if (!confirmed) return;
      _block();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    final keyboardIsOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final isTyping = _messageController.text.isNotEmpty;
    final hasMessages = _messages.isNotEmpty;

    final showProfileInAppBar = hasMessages || keyboardIsOpen || isTyping;
    final bgColor = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      appBar: AppBar(
        toolbarHeight: adaptiveHeight + (widget.skillName != null ? 8 : 0),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            ),
            if (showProfileInAppBar) ...[
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: _showProfile,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey,
                        backgroundImage: widget.avatarImage,
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
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Theme.of(context).colorScheme.surface,
              elevation: 6,
              offset: const Offset(0, 40),
              onSelected: _handleMenuAction,
              itemBuilder:
                  (context) => [
                    PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flag_outlined,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Report',
                            style: AppTextStyles.regularText.copyWith(
                              color: textTheme,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'block',
                      child: Row(
                        children: [
                          const Icon(Icons.block, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Block',
                            style: AppTextStyles.regularText.copyWith(
                              color: textTheme,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
              child: Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.more_horiz, color: textTheme, size: 22),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _loadingMessages
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null && _messages.isEmpty
                    ? _buildLoadError(textTheme)
                    : !hasMessages && !showProfileInAppBar
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _showProfile,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey,
                              backgroundImage: widget.avatarImage,
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
                    )
                    : _buildMessageList(textTheme),
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

  Widget _buildLoadError(Color textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(Color textTheme) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final mine = msg['sender_id'] == myId;
        final currTime = DateTime.tryParse(msg['created_at']?.toString() ?? '');
        DateTime? prevTime;
        if (i > 0) {
          prevTime = DateTime.tryParse(
            _messages[i - 1]['created_at']?.toString() ?? '',
          );
        }

        final showHeader =
            currTime != null &&
            ChatTimeFormatter.shouldShowMessengerHeader(prevTime, currTime);
        final messageKey =
            msg['id']?.toString() ??
            '${msg['created_at']}-${msg['sender_id']}-${msg['body']}';
        final isSelected = _expandedTimestamps.contains(messageKey);

        return Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
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
    );
  }
}
