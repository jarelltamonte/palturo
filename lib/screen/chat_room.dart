import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';

class ChatRoom extends StatefulWidget {
  final String name;
  final ImageProvider? avatarImage;

  const ChatRoom({
    super.key,
    required this.name,
    this.avatarImage,
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
        toolbarHeight: adaptiveHeight,
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

              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                backgroundImage: widget.avatarImage,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  widget.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.boldText.copyWith(
                    color: textTheme,
                  ),
                ),
              ),

              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  if (value == 'block') {
                    // Block user
                  } else if (value == 'report') {
                    // Report user
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'block',
                    child: Text('Block'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'report',
                    child: Text('Report'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),

      body: !_hasMessages && !showProfileInAppBar
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    backgroundImage: widget.avatarImage,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    widget.name,
                    style: AppTextStyles.boldText.copyWith(
                      color: textTheme,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
          : const Center(
              child: Text('Start messaging'),
            ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                      vertical: 12,
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
                  minimumSize: const Size(48, 48),
                  maximumSize: const Size(48, 48),
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