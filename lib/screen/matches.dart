import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/screen/users_dump.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/chats_page.dart' show SkillTag;
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/screen/home_page.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/screen/utils/pals_count.dart';
import 'package:palturo/screen/utils/filter_bottom_sheet.dart';
import 'package:palturo/widgets/app_skeleton.dart';
import 'package:palturo/utils/friendly_error.dart';
import 'package:palturo/widgets/user_avatar.dart';

enum RoleFilter { all, learner, mentor }

class Matches extends StatefulWidget {
  final VoidCallback? onStartSwiping;

  const Matches({super.key, this.onStartSwiping});

  @override
  State<Matches> createState() => _MatchesState();
}

class _MatchesState extends State<Matches> {
  static const List<String> _alphabet = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  final Map<String, GlobalKey> _sectionKeys = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String? _activeLetter;
  bool _isSearching = false;
  String _query = '';
  RoleFilter _roleFilter = RoleFilter.all;

  List<MatchedUser> _pals = const [];
  bool _loadingPals = true;
  String? _palsError;

  @override
  void initState() {
    super.initState();
    ChatStateService.instance.addListener(_onPalsChanged);
    _loadPals();
  }

  /// Single source of truth: ChatStateService accepted conversations.
  Future<void> _loadPals() async {
    setState(() {
      _loadingPals = true;
      _palsError = null;
    });
    await ChatStateService.instance.loadConversations(showSpinner: false);
    if (!mounted) return;
    if (ChatStateService.instance.error != null) {
      setState(() {
        _palsError = friendlyError(
          ChatStateService.instance.error ?? '',
          fallback: "Couldn't load your pals. Please try again.",
        );
        _loadingPals = false;
      });
      return;
    }
    _applyConversations(ChatStateService.instance.conversations);
  }

  void _onPalsChanged() {
    if (!mounted) return;
    if (ChatStateService.instance.loading) {
      setState(() => _loadingPals = true);
      return;
    }
    _applyConversations(ChatStateService.instance.conversations);
  }

  void _applyConversations(List<ConversationLite> conversations) {
    final pals =
        conversations
            .where((c) => c.status == 'accepted')
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
                avatarUrl: c.otherAvatar,
                connectionId: c.connectionId,
                otherUserId: c.otherUserId,
              ),
            )
            .toList();
    setState(() {
      _pals = pals;
      _loadingPals = false;
      _palsError = null;
    });
  }

  late final TapGestureRecognizer _swipeTap =
      TapGestureRecognizer()..onTap = _startSwiping;

  void _startSwiping() {
    final callback = widget.onStartSwiping;
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (!mounted) return;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  void dispose() {
    ChatStateService.instance.removeListener(_onPalsChanged);
    _swipeTap.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter => _roleFilter != RoleFilter.all;

  List<MatchedUser> _filteredPals() {
    final q = _query.trim().toLowerCase();
    return _pals.where((pal) {
      final matchesRole = switch (_roleFilter) {
        RoleFilter.all => true,
        RoleFilter.learner => pal.role == PersonRole.learner,
        RoleFilter.mentor => pal.role == PersonRole.mentor,
      };
      final matchesQuery = q.isEmpty || pal.name.toLowerCase().contains(q);
      return matchesRole && matchesQuery;
    }).toList();
  }

  Map<String, List<MatchedUser>> _groupedPals(List<MatchedUser> pals) {
    final sorted = [...pals]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final Map<String, List<MatchedUser>> grouped = {};
    for (final pal in sorted) {
      final name = pal.name.trim();
      final letter = name.isEmpty ? '#' : name[0].toUpperCase();
      grouped.putIfAbsent(letter, () => []).add(pal);
    }
    return grouped;
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

  void _jumpToLetter(String letter, Map<String, List<MatchedUser>> grouped) {
    final startIndex = _alphabet.indexOf(letter);
    String? target;
    for (int i = startIndex; i < _alphabet.length; i++) {
      if (grouped.containsKey(_alphabet[i])) {
        target = _alphabet[i];
        break;
      }
    }
    if (target == null) {
      for (int i = startIndex; i >= 0; i--) {
        if (grouped.containsKey(_alphabet[i])) {
          target = _alphabet[i];
          break;
        }
      }
    }
    if (target == null) return;

    setState(() => _activeLetter = target);

    final context = _sectionKeys[target]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, alignment: 0, duration: Duration.zero);
    }
  }

  Future<void> _unmatchPal(MatchedUser pal) async {
    if (!mounted) return;

    final connectionId = pal.connectionId;
    if (connectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This match isn’t available.')),
      );
      return;
    }

    try {
      await MatchApi.unmatch(connectionId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Remove pal failed: $e')));
      return;
    }

    // Keep the Chats tab in sync with the deleted connection.
    try {
      await ChatStateService.instance.loadConversations(showSpinner: false);
    } catch (_) {
      // The unmatch itself succeeded; the list will refresh on resume.
    }

    if (!mounted) return;
    setState(() => _pals.removeWhere((p) => p.id == pal.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You removed ${pal.name} from your Pals')),
    );
  }

  Future<void> _blockPal(MatchedUser pal) async {
    if (!mounted) return;

    final target = pal.otherUserId;
    if (target == null || target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This profile is unavailable right now.')),
      );
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
    await ChatStateService.instance.loadConversations(showSpinner: false);
    if (!mounted) return;
    setState(() => _pals.removeWhere((p) => p.id == pal.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('You blocked ${pal.name}')));
  }

  Future<void> _reportPal(MatchedUser pal, String reason) async {
    if (!mounted) return;

    final target = pal.otherUserId;
    if (target == null || target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This profile is unavailable right now.')),
      );
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

  Future<void> _handleAction(String action, MatchedUser pal) async {
    if (action == 'unmatch') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Remove pal',
        message:
            'Remove ${pal.name} from your Pals? You’ll lose this pal and your chat history.',
        confirmLabel: 'Remove pal',
      );
      if (!confirmed) return;
      _unmatchPal(pal);
    } else if (action == 'report') {
      final reason = await showReportReasonDialog(context, name: pal.name);
      if (reason == null) return;
      _reportPal(pal, reason);
    } else if (action == 'block') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Block',
        message:
            '${pal.name} won’t be able to find or message you, and will be removed from your Pals. You can unblock them anytime in Settings.',
        confirmLabel: 'Block',
      );
      if (!confirmed) return;
      _blockPal(pal);
    }
  }

  void _openChatRoom(MatchedUser pal) {
    _searchFocus.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChatRoom(
              name: pal.name,
              avatarImage: pal.avatarImage,
              skillName: pal.skillName,
              role: pal.role,
              person: pal.toPerson(),
              connectionId: pal.connectionId,
            ),
      ),
    );
  }

  void _openProfile(MatchedUser pal) {
    showPersonProfileDialog(
      context,
      pal.toPerson(),
      onUnmatch: () => _unmatchPal(pal),
      onBlock: () => _blockPal(pal),
      onReport: (reason) => _reportPal(pal, reason),
    );
  }

  void _showFilterSheet() {
    FilterBottomSheet.show(
      context,
      sections: const [
        FilterSection(
          key: 'role',
          title: 'Role',
          options: [
            FilterOption('All', 'all'),
            FilterOption('Learner', 'learner'),
            FilterOption('Mentor', 'mentor'),
          ],
        ),
      ],
      selected: {'role': _roleFilter.name},
      onApply: (result) {
        setState(() {
          _roleFilter = RoleFilter.values.firstWhere(
            (r) => r.name == result['role'],
            orElse: () => RoleFilter.all,
          );
        });
      },
    );
  }

  Widget _buildPalTile(MatchedUser pal, Color textTheme) {
    return InkWell(
      onTap: () => _openChatRoom(pal),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Semantics(
              container: true,
              button: true,
              label: 'View ${pal.name} profile',
              child: GestureDetector(
                onTap: () => _openProfile(pal),
                child: UserAvatar(
                  name: pal.name,
                  image: pal.avatarImage,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.regularText.copyWith(color: textTheme),
                  ),
                  const SizedBox(height: 2),
                  SkillTag(skillName: pal.skillName, role: pal.role),
                ],
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: textTheme),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) => _handleAction(value, pal),
                itemBuilder:
                    (context) => [
                      PopupMenuItem<String>(
                        value: 'unmatch',
                        child: Row(
                          children: [
                            Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.dangerText(context),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Remove pal',
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
                            Icon(
                              Icons.flag_outlined,
                              color: AppColors.dangerText(context),
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
                            Icon(
                              Icons.block,
                              color: AppColors.dangerText(context),
                              size: 20,
                            ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlphabetIndex(
    Map<String, List<MatchedUser>> grouped,
    Color textTheme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const laneHeight = 28.0;
        final maxRows = (constraints.maxHeight / laneHeight).floor().clamp(
          1,
          _alphabet.length,
        );
        final columnCount = (_alphabet.length / maxRows).ceil();
        final usedRows = (_alphabet.length / columnCount).ceil();

        Widget letterTile(String letter) {
          final hasItems = grouped.containsKey(letter);
          final isActive = _activeLetter == letter;
          return Semantics(
            button: true,
            label: 'Jump to $letter',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _jumpToLetter(letter, grouped);
                Future<void>.delayed(const Duration(milliseconds: 700), () {
                  if (mounted && _activeLetter == letter) {
                    setState(() => _activeLetter = null);
                  }
                });
              },
              child: SizedBox(
                width: 44,
                height: laneHeight,
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color:
                          isActive
                              ? AppColors.accentText(context)
                              : textTheme.withValues(
                                alpha: hasItems ? 0.9 : 0.5,
                              ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Center(
          child: SizedBox(
            width: columnCount * 44,
            height: usedRows * laneHeight,
            child: Column(
              children: [
                for (var row = 0; row < usedRows; row++)
                  Row(
                    children: [
                      for (var col = 0; col < columnCount; col++)
                        if (row * columnCount + col < _alphabet.length)
                          letterTile(_alphabet[row * columnCount + col])
                        else
                          const SizedBox(width: 44, height: laneHeight),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoPalsState(Color textTheme) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
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
                'No pals yet',
                style: AppTextStyles.boldText.copyWith(
                  color: textTheme,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Find someone who wants to exchange skills.',
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _startSwiping,
                child: const Text('Find people'),
              ),
            ],
          ),
        ),
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
              'No pals match your filters',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _searchFocus.unfocus();
                setState(() {
                  _query = '';
                  _roleFilter = RoleFilter.all;
                  _isSearching = false;
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgTheme = Theme.of(context).colorScheme.surface;
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;
    final filtered = _filteredPals();
    final grouped = _groupedPals(filtered);
    final isFiltered =
        (_hasActiveFilter || _query.trim().isNotEmpty) &&
        filtered.length != _pals.length;
    final countText =
        isFiltered
            ? '${filtered.length} of ${_pals.length}'
            : '${filtered.length}';

    return Scaffold(
      backgroundColor: bgTheme,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title:
            _isSearching
                ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Container(
                    height: 44,
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
                            onChanged:
                                (value) => setState(() => _query = value),
                            textInputAction: TextInputAction.search,
                            style: AppTextStyles.regularText.copyWith(
                              color: textTheme,
                            ),
                            cursorColor: AppColors.accentText(context),
                            decoration: InputDecoration(
                              hintText: 'Search pals',
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
                  ),
                )
                : Row(
                  children: [
                    Semantics(
                      container: true,
                      button: true,
                      label: 'Back',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(context),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: textTheme,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'Pals',
                      style: AppTextStyles.headingText.copyWith(
                        color: textTheme,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSearching)
                  TextButton(
                    onPressed: _stopSearch,
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Search pals',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: Icon(CupertinoIcons.search, color: textTheme),
                    onPressed: _startSearch,
                  ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Filter pals',
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: Icon(Icons.tune, color: textTheme),
                      onPressed: _showFilterSheet,
                    ),
                    if (_hasActiveFilter)
                      Positioned(
                        right: 8,
                        top: 8,
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
              ],
            ),
          ),
        ],
      ),
      body:
          _loadingPals
              ? const MatchesSkeleton()
              : _palsError != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _palsError!,
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadPals,
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
              )
              : _pals.isEmpty
              ? _buildNoPalsState(textTheme)
              : SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Semantics(
                                label:
                                    isFiltered
                                        ? '${filtered.length} of ${palCountLabel(_pals.length)}'
                                        : palCountLabel(filtered.length),
                                excludeSemantics: true,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _pals.length > 1
                                          ? 'Your Pals'
                                          : 'Your Pal',
                                      style: AppTextStyles.headingText.copyWith(
                                        color: textTheme,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      countText,
                                      style: AppTextStyles.regularText.copyWith(
                                        color: AppColors.mutedText(context),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (filtered.isEmpty) _buildEmptyState(textTheme),
                            for (final entry in grouped.entries) ...[
                              Padding(
                                key: _sectionKeys.putIfAbsent(
                                  entry.key,
                                  () => GlobalKey(),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  4,
                                ),
                                child: Text(
                                  entry.key,
                                  style: AppTextStyles.regularText.copyWith(
                                    color: textTheme.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              for (final pal in entry.value)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 4,
                                  ),
                                  child: _buildPalTile(pal, textTheme),
                                ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    _buildAlphabetIndex(grouped, textTheme),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
    );
  }
}