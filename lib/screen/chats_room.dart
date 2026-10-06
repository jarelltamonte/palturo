import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/chats_page.dart' show SkillTag;
import 'package:palturo/screen/block_list.dart';
import 'package:palturo/screen/action_dialogs.dart';

class ChatRoom extends StatefulWidget {
  final String name;
  final ImageProvider? avatarImage;
  final String? skillName;
  final PersonRole? role;
  final Person? person;

  const ChatRoom({
    super.key,
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

  bool _hasMessages = false;

  @override
  void initState() {
    super.initState();

    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();

    if (message.isEmpty) return;

    setState(() {
      _hasMessages = true;
    });

    _messageController.clear();
  }

  Person get _personForBlock {
    return widget.person ??
        Person(
          id: widget.name,
          name: widget.name,
          schedule: '',
          language: '',
          learningStyle: '',
          skillName: widget.skillName ?? '',
          role: widget.role ?? PersonRole.learner,
        );
  }

  void _leaveChat(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _unmatch() {
    _leaveChat('You unmatched ${widget.name}');
  }

  void _block() {
    BlockedUsers.block(_personForBlock);
    _leaveChat('You blocked ${widget.name}');
  }

  void _report(String reason) {
    if (!mounted) return;
    debugPrint('Reported ${widget.name}: $reason');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks for your report.')),
    );
  }

  void _showProfile() {
    final person = widget.person;
    if (person == null) return;
    showPersonProfileDialog(
      context,
      person,
      onUnmatch: _unmatch,
      onBlock: _block,
      onReport: _report,
    );
  }

  Future<void> _handleMenuAction(String action) async {
    FocusScope.of(context).unfocus();

    if (action == 'unmatch') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Unmatch',
        message:
            'Unmatch ${widget.name}? You’ll lose this match and your chat history.',
        confirmLabel: 'Unmatch',
      );
      if (!confirmed) return;
      _unmatch();
    } else if (action == 'report') {
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

    final showProfileInAppBar = _hasMessages || keyboardIsOpen || isTyping;

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
                  value: 'unmatch',
                  child: Row(
                    children: [
                      const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Unmatch',
                        style: AppTextStyles.regularText.copyWith(
                          color: textTheme,
                        ),
                      ),
                    ],
                  ),
                ),
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
      body: !_hasMessages && !showProfileInAppBar
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
          : const Center(
              child: Text('Start messaging'),
            ),
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
}