import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/screen/matches.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/users_dump.dart';

enum ChatRoleFilter { all, learner, mentor }

enum ChatReadFilter { all, unread, read }

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
  ChatRoleFilter _roleFilter = ChatRoleFilter.all;
  ChatReadFilter _readFilter = ChatReadFilter.all;

  final List<MatchedUser> _chats = dumpUsers;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter =>
      _roleFilter != ChatRoleFilter.all || _readFilter != ChatReadFilter.all;

  bool _matchesRole(MatchedUser chat) {
    switch (_roleFilter) {
      case ChatRoleFilter.all:
        return true;
      case ChatRoleFilter.learner:
        return chat.role == PersonRole.learner;
      case ChatRoleFilter.mentor:
        return chat.role == PersonRole.mentor;
    }
  }

  bool _matchesRead(MatchedUser chat) {
    switch (_readFilter) {
      case ChatReadFilter.all:
        return true;
      case ChatReadFilter.unread:
        return chat.hasUnread;
      case ChatReadFilter.read:
        return !chat.hasUnread;
    }
  }

  List<MatchedUser> get _filteredMatches {
    final q = _query.trim().toLowerCase();
    return _chats.where((c) {
      final matchesQuery = q.isEmpty || c.name.toLowerCase().contains(q);
      return matchesQuery && _matchesRole(c);
    }).toList();
  }

  List<MatchedUser> get _filteredMessages {
    final q = _query.trim().toLowerCase();
    return _chats.where((c) {
      if (c.lastMessage == null) return false;
      final matchesQuery =
          q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.lastMessage!.toLowerCase().contains(q);
      return matchesQuery && _matchesRole(c) && _matchesRead(c);
    }).toList();
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
    String? skillName,
    PersonRole? role,
    Person? person,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChatRoom(
              name: name,
              avatarImage: avatarImage,
              skillName: skillName,
              role: role,
              person: person,
            ),
      ),
    );
  }

  void _openMatches(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Matches()),
    );
  }

  Widget _sheetSectionLabel(String label, Color textColor) {
    return Text(
      label,
      style: AppTextStyles.regularText.copyWith(
        color: textColor.withValues(alpha: 0.6),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _filterChip(
    String label,
    bool selected,
    VoidCallback onTap,
    Color primaryColor,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primaryColor : textColor.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.regularText.copyWith(
            color: selected ? Colors.black : textColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _openFilterSheet() {
    final bgColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.secondary;
    ChatRoleFilter draftRole = _roleFilter;
    ChatReadFilter draftRead = _readFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filters',
                            style: AppTextStyles.boldText.copyWith(
                              color: textColor,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              () => setModalState(() {
                                draftRole = ChatRoleFilter.all;
                                draftRead = ChatReadFilter.all;
                              }),
                          child: Text(
                            'Reset',
                            style: AppTextStyles.regularText.copyWith(
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _sheetSectionLabel('Role', textColor),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip(
                          'All',
                          draftRole == ChatRoleFilter.all,
                          () => setModalState(
                            () => draftRole = ChatRoleFilter.all,
                          ),
                          AppColors.primary,
                          textColor,
                        ),
                        _filterChip(
                          'Learner',
                          draftRole == ChatRoleFilter.learner,
                          () => setModalState(
                            () => draftRole = ChatRoleFilter.learner,
                          ),
                          AppColors.primary,
                          textColor,
                        ),
                        _filterChip(
                          'Mentor',
                          draftRole == ChatRoleFilter.mentor,
                          () => setModalState(
                            () => draftRole = ChatRoleFilter.mentor,
                          ),
                          AppColors.primary,
                          textColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sheetSectionLabel('Status', textColor),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip(
                          'All',
                          draftRead == ChatReadFilter.all,
                          () => setModalState(
                            () => draftRead = ChatReadFilter.all,
                          ),
                          AppColors.primary,
                          textColor,
                        ),
                        _filterChip(
                          'Unread',
                          draftRead == ChatReadFilter.unread,
                          () => setModalState(
                            () => draftRead = ChatReadFilter.unread,
                          ),
                          AppColors.primary,
                          textColor,
                        ),
                        _filterChip(
                          'Read',
                          draftRead == ChatReadFilter.read,
                          () => setModalState(
                            () => draftRead = ChatReadFilter.read,
                          ),
                          AppColors.primary,
                          textColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sheetSectionLabel('Skills', textColor),
                    const SizedBox(height: 8),
                    Text(
                      'Coming soon',
                      style: AppTextStyles.regularText.copyWith(
                        color: textColor.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            _roleFilter = draftRole;
                            _readFilter = draftRead;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Apply',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  Widget _buildNoMatchesState(Color textTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 110),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/empty.json',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text(
              'No matches yet',
              style: AppTextStyles.boldText.copyWith(
                color: textTheme,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Once you match with someone, your chats will show up here.',
              textAlign: TextAlign.center,
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
    final hasNoChats = _chats.isEmpty;

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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _startSearch,
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            CupertinoIcons.search,
                            color: textTheme,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: _openFilterSheet,
                          behavior: HitTestBehavior.opaque,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(Icons.tune, color: textTheme, size: 24),
                              if (_hasActiveFilter)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
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
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (!hasNoChats && (matches.isNotEmpty || showShortcut)) ...[
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
                      final ImageProvider? avatarImage = chat.avatarImage;

                      return ChatProfileItem(
                        name: chat.name,
                        avatarImage: avatarImage,
                        onTap:
                            () => _openChatRoom(
                              context,
                              name: chat.name,
                              avatarImage: avatarImage,
                              skillName: chat.skillName,
                              role: chat.role,
                              person: chat.toPerson(),
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
                  final ImageProvider? avatarImage = chat.avatarImage;

                  return ChatListItem(
                    name: chat.name,
                    message: chat.lastMessage!,
                    time: chat.lastMessageTime ?? '',
                    hasUnread: chat.hasUnread,
                    skillName: chat.skillName,
                    role: chat.role,
                    avatarImage: avatarImage,
                    onTap:
                        () => _openChatRoom(
                          context,
                          name: chat.name,
                          avatarImage: avatarImage,
                          skillName: chat.skillName,
                          role: chat.role,
                          person: chat.toPerson(),
                        ),
                  );
                },
              ),
            ],
            if (hasNoChats)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildNoMatchesState(textTheme),
              )
            else ...[
              if (nothingFound)
                SliverToBoxAdapter(child: _buildEmptyState(textTheme)),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
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
  final String? skillName;
  final PersonRole? role;
  final ImageProvider? avatarImage;
  final VoidCallback? onTap;

  const ChatListItem({
    super.key,
    this.name = 'Random Name',
    this.message = 'Random chat message goes here',
    this.time = 'Just now',
    this.hasUnread = true,
    this.skillName,
    this.role,
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
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.boldText.copyWith(
                            color: textTheme,
                          ),
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
                      if (skillName != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: SkillTag(skillName: skillName!, role: role),
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

class SkillTag extends StatelessWidget {
  final String skillName;
  final PersonRole? role;

  const SkillTag({super.key, required this.skillName, this.role});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final iconAsset =
        role == PersonRole.mentor
            ? 'assets/icons/rmentor.svg'
            : 'assets/icons/rlearner.svg';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: textTheme.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (role != null) ...[
            SvgPicture.asset(iconAsset, width: 14, height: 14),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              skillName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}