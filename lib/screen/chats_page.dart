import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/screen/matches.dart';

class ChatPreview {
  final String name;
  final String message;
  final String time;
  final bool hasUnread;

  const ChatPreview({
    required this.name,
    required this.message,
    required this.time,
    this.hasUnread = false,
  });
}

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _isSearching = false;
  String _query = '';

  final List<ChatPreview> _chats = const [
    ChatPreview(
      name: 'Aaliyah Reyes',
      message: 'Are we still on for tomorrow?',
      time: 'Just now',
      hasUnread: true,
    ),
    ChatPreview(
      name: 'Benjie Cruz',
      message: 'Thanks for the tips on the project!',
      time: '5m',
      hasUnread: true,
    ),
    ChatPreview(
      name: 'Carla Mendoza',
      message: 'Sent you the notes from class',
      time: '23m',
    ),
    ChatPreview(
      name: 'Dani Navarro',
      message: 'Can we move our session to Friday?',
      time: '1h',
      hasUnread: true,
    ),
    ChatPreview(
      name: 'Elise Tan',
      message: 'That sounds great, let me know',
      time: '3h',
    ),
    ChatPreview(
      name: 'Gab Aquino',
      message: 'Haha that was so funny',
      time: 'Yesterday',
    ),
    ChatPreview(
      name: 'Jasmine Flores',
      message: 'See you at the meetup!',
      time: 'Yesterday',
    ),
    ChatPreview(
      name: 'Maya Domingo',
      message: 'I will send the files later tonight',
      time: 'Mon',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<ChatPreview> get _filteredMatches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _chats;
    return _chats.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  List<ChatPreview> get _filteredMessages {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _chats;
    return _chats
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.message.toLowerCase().contains(q),
        )
        .toList();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  void _stopSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _isSearching = false;
      _query = '';
    });
  }

  void _openChatRoom(
    BuildContext context, {
    required String name,
    ImageProvider? avatarImage,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoom(name: name, avatarImage: avatarImage),
      ),
    );
  }

  void _openMatches(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Matches()),
    );
  }

  Widget _buildSearchField(Color textTheme, Color primaryColor) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: textTheme.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            size: 18,
            color: textTheme.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: AppTextStyles.regularText.copyWith(color: textTheme),
              cursorColor: primaryColor,
              decoration: InputDecoration(
                hintText: 'Search chats',
                hintStyle: AppTextStyles.regularText.copyWith(
                  color: textTheme.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              child: Icon(
                Icons.cancel,
                size: 18,
                color: textTheme.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textTheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 40,
              color: textTheme.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No chats found',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    final matches = _filteredMatches;
    final messages = _filteredMessages;
    final nothingFound = matches.isEmpty && messages.isEmpty;
    final showShortcut = _query.trim().isEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title:
            _isSearching
                ? _buildSearchField(textTheme, primaryColor)
                : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chats',
                      style: AppTextStyles.headingText.copyWith(
                        color: textTheme,
                      ),
                    ),
                    GestureDetector(
                      onTap: _startSearch,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        CupertinoIcons.search,
                        color: textTheme,
                        size: 24,
                      ),
                    ),
                  ],
                ),
        actions:
            _isSearching
                ? [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: TextButton(
                      onPressed: _stopSearch,
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.regularText.copyWith(
                          color: textTheme,
                        ),
                      ),
                    ),
                  ),
                ]
                : null,
      ),
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (matches.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Text(
                    'Your matches',
                    style: AppTextStyles.boldText.copyWith(color: textTheme),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    itemCount: matches.length + (showShortcut ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (showShortcut && index == 0) {
                        return MatchesShortcutItem(
                          onTap: () => _openMatches(context),
                        );
                      }
                      final chat = matches[showShortcut ? index - 1 : index];
                      const ImageProvider? avatarImage = null;

                      return ChatProfileItem(
                        name: chat.name,
                        avatarImage: avatarImage,
                        onTap:
                            () => _openChatRoom(
                              context,
                              name: chat.name,
                              avatarImage: avatarImage,
                            ),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (messages.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, bottom: 8),
                  child: Text(
                    'Messages',
                    style: AppTextStyles.boldText.copyWith(color: textTheme),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final chat = messages[index];
                  const ImageProvider? avatarImage = null;

                  return ChatListItem(
                    name: chat.name,
                    message: chat.message,
                    time: chat.time,
                    hasUnread: chat.hasUnread,
                    avatarImage: avatarImage,
                    onTap:
                        () => _openChatRoom(
                          context,
                          name: chat.name,
                          avatarImage: avatarImage,
                        ),
                  );
                },
              ),
            ],
            if (nothingFound)
              SliverToBoxAdapter(child: _buildEmptyState(textTheme)),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

class MatchesShortcutItem extends StatelessWidget {
  final VoidCallback? onTap;

  const MatchesShortcutItem({super.key, this.onTap});

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
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                CupertinoIcons.person_3_fill,
                color: textTheme,
                size: 36,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 100,
              child: Text(
                'All',
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
                image:
                    avatarImage != null
                        ? DecorationImage(
                          image: avatarImage!,
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  avatarImage == null
                      ? Icon(Icons.person, color: Colors.grey[600], size: 28)
                      : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 100,
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
              child:
                  avatarImage == null
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
                        style: AppTextStyles.boldText.copyWith(
                          color: textTheme,
                        ),
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