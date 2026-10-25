import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/gestures.dart';
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
import 'package:palturo/screen/home_page.dart';
import 'package:palturo/screen/utils/filter_bottom_sheet.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/screen/utils/chat_time_formatter.dart';
import 'package:palturo/widgets/app_skeleton.dart';
import 'package:palturo/widgets/user_avatar.dart';

class ChatsPage extends StatefulWidget {
  final VoidCallback? onStartSwiping;

  const ChatsPage({super.key, this.onStartSwiping});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _isSearching = false;
  String _query = '';

  Map<String, String> _filters = {'role': 'all', 'status': 'all'};

  static const List<FilterSection> _filterSections = [
    FilterSection(
      key: 'role',
      title: 'Role',
      options: [
        FilterOption('View all', 'all'),
        FilterOption('Learner', 'learner'),
        FilterOption('Mentor', 'mentor'),
      ],
    ),
    FilterSection(
      key: 'status',
      title: 'Status',
      options: [
        FilterOption('View all', 'all'),
        FilterOption('Unread', 'unread'),
        FilterOption('Read', 'read'),
      ],
    ),
  ];

  static const int _maxMatchCards = 8;

  List<MatchedUser> get _chats =>
      ChatStateService.instance.conversations
          .map(
            (c) => MatchedUser(
              id: '${c.connectionId}|${c.otherUserId}',
              name: c.otherName,
              role:
                  c.otherRole == 'learner'
                      ? PersonRole.learner
                      : PersonRole.mentor,
              skillName: c.otherSkill ?? '',
              category: SkillCategory.everydayPractical,
              schedule: '',
              language: '',
              learningStyle: '',
              lastMessage: c.lastMessage,
              lastMessageTime: ChatTimeFormatter.formatChatListTime(c.lastAt),
              hasUnread: c.unread > 0,
              avatarUrl: c.otherAvatar,
              connectionId: c.connectionId,
              otherUserId: c.otherUserId,
            ),
          )
          .toList();

  bool get _loadingChats => ChatStateService.instance.loading;
  String? get _chatsError => ChatStateService.instance.error;

  late final TapGestureRecognizer _swipeTap =
      TapGestureRecognizer()..onTap = _startSwiping;

  @override
  void initState() {
    super.initState();
    ChatStateService.instance.addListener(_onChatStateChanged);
    _loadChats();
  }

  void _onChatStateChanged() {
    if (!mounted) return;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _loadChats() async {
    await ChatStateService.instance.loadConversations();
  }

  @override
  void dispose() {
    ChatStateService.instance.removeListener(_onChatStateChanged);
    _swipeTap.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _startSwiping() {
    final callback = widget.onStartSwiping;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  bool get _hasActiveFilter =>
      _filters['role'] != 'all' || _filters['status'] != 'all';

  bool _matchesRole(MatchedUser chat) {
    switch (_filters['role']) {
      case 'learner':
        return chat.role == PersonRole.learner;
      case 'mentor':
        return chat.role == PersonRole.mentor;
      default:
        return true;
    }
  }

  bool _matchesRead(MatchedUser chat) {
    switch (_filters['status']) {
      case 'unread':
        return chat.hasUnread;
      case 'read':
        return !chat.hasUnread;
      default:
        return true;
    }
  }

  List<MatchedUser> get _filteredMatches {
    final q = _query.trim().toLowerCase();
    return _chats.where((c) {
      final matchesQuery = q.isEmpty || c.name.toLowerCase().contains(q);
      return matchesQuery && _matchesRole(c) && _matchesRead(c);
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
    String? connectionId,
  }) async {
    if (connectionId != null) {
      ChatStateService.instance.enterRoom(connectionId);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChatRoom(
              name: name,
              avatarImage: avatarImage,
              skillName: skillName,
              role: role,
              person: person,
              connectionId: connectionId,
            ),
      ),
    );
    if (connectionId != null) {
      ChatStateService.instance.leaveRoom(connectionId);
    }
  }

  void _openMatches(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Matches(onStartSwiping: _startSwiping),
      ),
    );
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      sections: _filterSections,
      selected: _filters,
      onApply: (result) => setState(() => _filters = result),
    );
  }

  Widget _buildSearchField(Color textTheme, Color primaryColor) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: textTheme.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
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
            Semantics(
              container: true,
              button: true,
              label: 'Clear search',
              child: GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.cancel,
                      size: 18,
                      color: textTheme.withValues(alpha: 0.5),
                    ),
                  ),
                ),
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
              _hasActiveFilter && _query.trim().isEmpty
                  ? 'No chats match your filters'
                  : 'No chats found',
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
            Text.rich(
              TextSpan(
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme.withValues(alpha: 0.7),
                ),
                children: [
                  const TextSpan(text: 'Start '),
                  TextSpan(
                    text: 'Swiping',
                    recognizer: _swipeTap,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentText(context),
                      decoration: TextDecoration.underline,
                      decorationThickness: 1.5,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    final matches = _filteredMatches;
    final visibleMatches = matches.take(_maxMatchCards).toList();
    final messages = _filteredMessages;
    final nothingFound = matches.isEmpty && messages.isEmpty;
    final showShortcut = _query.trim().isEmpty;
    final hasNoChats = _chats.isEmpty;
    final showMatchesSection =
        !hasNoChats &&
        (matches.isNotEmpty || (showShortcut && !_hasActiveFilter));

    if (_loadingChats) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const ListRowsSkeleton(),
      );
    }
    if (_chatsError != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          toolbarHeight: adaptiveHeight,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Text(
            'Chats',
            style: AppTextStyles.headingText.copyWith(color: textTheme),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Couldn’t load your chats.\nPlease check your connection.',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadChats,
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
                ? _buildSearchField(textTheme, AppColors.accentText(context))
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
                        IconButton(
                          tooltip: 'Search chats',
                          onPressed: _startSearch,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          icon: Icon(
                            CupertinoIcons.search,
                            color: textTheme,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Semantics(
                          container: true,
                          button: true,
                          label: 'Filter chats',
                          child: GestureDetector(
                            onTap: _openFilterSheet,
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Align(
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.tune,
                                      color: textTheme,
                                      size: 24,
                                    ),
                                  ),
                                  if (_hasActiveFilter)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.accentText(context),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
            if (showMatchesSection) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Text(
                    'Your Pals',
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
                    itemCount: visibleMatches.length + (showShortcut ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (showShortcut && index == 0) {
                        return MatchesShortcutItem(
                          onTap: () => _openMatches(context),
                        );
                      }
                      final chat =
                          visibleMatches[showShortcut ? index - 1 : index];
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
                              connectionId: chat.connectionId,
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
                          connectionId: chat.connectionId,
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
              child: const Icon(
                CupertinoIcons.person_3_fill,
                color: AppColors.black,
                size: 36,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 100,
              child: Text(
                'View all',
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
            UserAvatar(
              name: name,
              image: avatarImage,
              size: 100,
              height: 120,
              circular: false,
              borderRadius: 12,
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
            UserAvatar(name: name, image: avatarImage, size: 56),
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
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      if (skillName != null &&
                          skillName!.trim().isNotEmpty) ...[
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
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          time,
                          style: AppTextStyles.regularText.copyWith(
                            color: textTheme.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
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
    if (skillName.trim().isEmpty) return const SizedBox.shrink();
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
