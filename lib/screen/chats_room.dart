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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loadingMessages = false;
  StreamSubscription? _messageStream;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {});
    });
    _loadMessages();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _messageStream?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _loadMessages() async {
    if (widget.connectionId == null) return;
    setState(() => _loadingMessages = true);
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
      setState(() => _loadingMessages = false);
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
          });
          _scrollToBottom();
        });
  }

  List<Map<String, dynamic>> _sortMessages(List<Map<String, dynamic>> rows) {
    final sorted = [...rows];
    sorted.sort(
      (a, b) => (DateTime.tryParse(a['created_at']?.toString() ?? '')
              ?.compareTo(
                DateTime.tryParse(b['created_at']?.toString() ?? '')
                    ?? DateTime(1900),
              ))
          ?? 0,
    );
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
    _messageController.clear();
    try {
      await MatchApi.sendMessage(widget.connectionId!, message);
      // realtime stream refreshes the thread
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  void _leaveChat(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _block() async {
    final target =
        widget.person?.id ?? widget.connectionId ?? widget.name;
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
    final target =
        widget.person?.id ?? widget.connectionId ?? widget.name;
    try {
      await MatchApi.reportUser(target, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your report.')),
      );
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

    if (action == 'report') {
      final reason = await showReportReasonDialog(
        context,
        name: widget.name,
      );
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
    final primaryColor = Theme.of(context).colorScheme.primary;

    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    final keyboardIsOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final isTyping = _messageController.text.isNotEmpty;
    final hasMessages = _messages.isNotEmpty;

    final showProfileInAppBar = hasMessages || keyboardIsOpen || isTyping;

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
                            if (widget.skillName != null) ...[
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
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined,
                          color: Colors.red, size: 20),
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
                child: Icon(
                  Icons.more_horiz,
                  color: textTheme,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
      body: !hasMessages && !showProfileInAppBar
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
                  if (widget.skillName != null) ...[
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
          : _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _buildMessageList(textTheme),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  style: AppTextStyles.regularText.copyWith(
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    filled: true,
                    fillColor: AppColors.secondary,
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
                        color: primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  minimumSize: const Size(58, 58),
                  maximumSize: const Size(58, 58),
                ),
                icon: const Icon(
                  Icons.send_rounded,
                  size: 21,
                ),
              ),
            ],
          ),
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
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: mine
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
        );
      },
    );
  }
}
