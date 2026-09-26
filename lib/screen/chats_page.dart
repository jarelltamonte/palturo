import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/screen/chats_room.dart'; 

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  void _openChatRoom(BuildContext context, {
    required String name,
    ImageProvider? avatarImage,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoom(
          name: name,
          avatarImage: avatarImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chats',
              style: AppTextStyles.headingText.copyWith(color: textTheme),
            ),
            Icon(
              CupertinoIcons.search,
              color: textTheme,
              size: 24,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemCount: 8, // placeholder count until wired to DB
                itemBuilder: (context, index) {
                  const name = 'Random Name'; // swap for real data later
                  const avatarImage = null; // swap for real data later

                  return ChatProfileItem(
                    name: name,
                    avatarImage: avatarImage,
                    onTap: () => _openChatRoom(
                      context,
                      name: name,
                      avatarImage: avatarImage,
                    ),
                  );
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Text(
                    'Messages',
                    style: AppTextStyles.boldText.copyWith(color: textTheme),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    'Requests',
                    style: AppTextStyles.regularText.copyWith(color: textTheme),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: 8, // placeholder count until wired to DB
                itemBuilder: (context, index) {
                  const name = 'Random Name'; // swap for real data later
                  const avatarImage = null; // swap for real data later

                  return ChatListItem(
                    name: name,
                    message: 'Random chat message goes here',
                    time: 'Just now',
                    hasUnread: true,
                    avatarImage: avatarImage,
                    onTap: () => _openChatRoom(
                      context,
                      name: name,
                      avatarImage: avatarImage,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatProfileItem extends StatelessWidget {
  final String name;
  final ImageProvider? avatarImage;
  final VoidCallback? onTap;

  const ChatProfileItem({
    super.key,
    this.name = 'Random Name',
    this.avatarImage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
                image: avatarImage != null
                    ? DecorationImage(
                        image: avatarImage!,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarImage == null
                  ? Icon(Icons.person, color: Colors.grey[600], size: 28)
                  : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatListItem extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final bool hasUnread;
  final ImageProvider? avatarImage;
  final VoidCallback? onTap;

  const ChatListItem({
    super.key,
    this.name = 'Random Name',
    this.message = 'Random chat message goes here',
    this.time = 'Just now',
    this.hasUnread = true,
    this.avatarImage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[300],
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Icon(Icons.person, color: Colors.grey[600], size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.boldText.copyWith(color: textTheme),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.regularText.copyWith(
                            color: textTheme.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      Text(
                        ' · $time',
                        style: AppTextStyles.regularText.copyWith(
                          color: textTheme.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}