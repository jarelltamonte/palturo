import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/widgets/app_chrome.dart';
import 'package:palturo/theme/app_spacing.dart';
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
import 'package:palturo/widgets/app_feedback.dart';

/// Role filter options for the pals list.
enum RoleFilter { all, learner, mentor }

/// "Pals" screen: shows all accepted connections, grouped alphabetically,
/// with search, role filtering and an A-Z quick-jump index.
class Matches extends StatefulWidget {
  /// Optional callback used by the empty state to send the user back to swiping.
  final VoidCallback? onStartSwiping;

  const Matches({super.key, this.onStartSwiping});

  @override
  State<Matches> createState() => _MatchesState();
}

class _MatchesState extends State<Matches> {
  // Letters shown in the side index.
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

  // One GlobalKey per letter section, used to scroll to that section.
  final Map<String, GlobalKey> _sectionKeys = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String? _activeLetter; // Letter currently highlighted in the index.
  bool _isSearching = false; // Whether the app bar shows the search field.
  String _query = ''; // Current search text.
  RoleFilter _roleFilter = RoleFilter.all;

  List<MatchedUser> _pals = const [];
  bool _loadingPals = true;
  String? _palsError;

  @override
  void initState() {
    super.initState();
    // Rebuild the list whenever the shared chat state changes.
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

  /// Listener for ChatStateService updates.
  void _onPalsChanged() {
    if (!mounted) return;
    if (ChatStateService.instance.loading) {
      setState(() => _loadingPals = true);
      return;
    }
    _applyConversations(ChatStateService.instance.conversations);
  }

  /// Converts accepted conversations into [MatchedUser] items for display.
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

  // Tap recognizer (kept for tappable text spans / "start swiping" actions).
  late final TapGestureRecognizer _swipeTap =
      TapGestureRecognizer()..onTap = _startSwiping;

  /// Sends the user back to the swiping screen.
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

  // True when any non-default filter is applied.
  bool get _hasActiveFilter => _roleFilter != RoleFilter.all;

  /// Applies the role filter and the search query to the pals list.
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

  /// Sorts pals by name and groups them by first letter ('#' for empty names).
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

  /// Switches the app bar into search mode and focuses the field.
  void _startSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  /// Leaves search mode and clears the query.
  void _stopSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _isSearching = false;
      _query = '';
    });
  }

  /// Scrolls to the given letter's section. If that letter has no pals, falls
  /// forward to the next letter that does, then backward if none is found.
  void _jumpToLetter(String letter, Map<String, List<MatchedUser>> grouped) {
    final startIndex = _alphabet.indexOf(letter);
    String? target;
    // Look forward first.
    for (int i = startIndex; i < _alphabet.length; i++) {
      if (grouped.containsKey(_alphabet[i])) {
        target = _alphabet[i];
        break;
      }
    }
    // Otherwise look backward.
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

  /// Removes the pal (deletes the connection) and refreshes local state.
  Future<void> _unmatchPal(MatchedUser pal) async {
    if (!mounted) return;

    final connectionId = pal.connectionId;
    if (connectionId == null) {
      showAppSnackBar(context, 'This match isn’t available.');
      return;
    }

    try {
      await MatchApi.unmatch(connectionId);
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        friendlyError(
          e,
          fallback: 'Could not remove this Pal. Please try again.',
        ),
      );
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
    showAppSuccess(context, 'You removed ${pal.name} from your Pals');
  }

  /// Blocks the pal's user account and removes them from the list.
  Future<void> _blockPal(MatchedUser pal) async {
    if (!mounted) return;

    final target = pal.otherUserId;
    if (target == null || target.isEmpty) {
      showAppSnackBar(context, 'This profile is unavailable right now.');
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
    if (!mounted) return;
    setState(() => _pals.removeWhere((p) => p.id == pal.id));
    showAppSuccess(context, 'You blocked ${pal.name}');
  }

  /// Reports the pal's user account with the chosen reason.
  Future<void> _reportPal(MatchedUser pal, String reason) async {
    if (!mounted) return;

    final target = pal.otherUserId;
    if (target == null || target.isEmpty) {
      showAppSnackBar(context, 'This profile is unavailable right now.');
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

  /// Handles a selection from the "..." popup menu (with confirmations).
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

  /// Opens the chat room with the given pal.
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

  /// Opens the pal's profile dialog (with unmatch / block / report callbacks).
  void _openProfile(MatchedUser pal) {
    showPersonProfileDialog(
      context,
      pal.toPerson(),
      onUnmatch: () => _unmatchPal(pal),
      onBlock: () => _blockPal(pal),
      onReport: (reason) => _reportPal(pal, reason),
    );
  }

  /// Shows the filter bottom sheet and applies the selected role filter.
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

  /// One row in the pals list.
  /// - Tapping the avatar opens the profile.
  /// - Tapping anywhere else on the row opens the chat room.
  /// - The "..." menu handles its own taps (remove / report / block).
  Widget _buildPalTile(MatchedUser pal, Color textTheme) {
    return InkWell(
      // CHANGED: the whole row now opens the chat room (was: open profile).
      onTap: () => _openChatRoom(pal),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Avatar: the only part of the row that opens the profile.
            // Its own GestureDetector wins over the row's InkWell, so the
            // tap won't also trigger the chat room.
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
            // Name + skill tag (taps fall through to the row -> chat room).
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
            // REMOVED: the chat bubble IconButton. The row itself now opens
            // the chat room.

            // "..." menu with remove / report / block actions.
            SizedBox(
              width: AppSpacing.iconTarget,
              height: AppSpacing.iconTarget,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: textTheme),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) => _handleAction(value, pal),
                itemBuilder:
                    (context) => [
                      // Remove pal
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
                      // Report
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
                      // Block
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

  /// A-Z side index. Lays letters out in as many columns as needed so they
  /// all fit in the available height.
  Widget _buildAlphabetIndex(
    Map<String, List<MatchedUser>> grouped,
    Color textTheme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const laneHeight = 28.0;
        // How many letters fit vertically in one column.
        final maxRows = (constraints.maxHeight / laneHeight).floor().clamp(
          1,
          _alphabet.length,
        );
        final columnCount = (_alphabet.length / maxRows).ceil();
        final usedRows = (_alphabet.length / columnCount).ceil();

        // A single tappable letter. Dimmed when that section has no pals.
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
                // Clear the highlight shortly after the jump.
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

  /// Empty state shown when the user has no pals at all.
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

  /// Empty state shown when pals exist but none match the search/filter.
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
            // Resets search text, role filter and search mode.
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
    final adaptiveHeight = AppSpacing.topBarHeight();
    final filtered = _filteredPals();
    final grouped = _groupedPals(filtered);
    // True when the visible list is smaller than the full list due to filters.
    final isFiltered =
        (_hasActiveFilter || _query.trim().isNotEmpty) &&
        filtered.length != _pals.length;
    // e.g. "3 of 10" when filtered, otherwise just the count.
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
        leadingWidth: AppSpacing.leadingWidth,
        titleSpacing: AppSpacing.titleSpacing,
        // Hide the back button while searching.
        leading:
            _isSearching
                ? null
                : AppChrome.backButton(context, color: textTheme),
        // Title is either the search field or the "Pals" heading.
        title:
            _isSearching
                ? Padding(
                  padding: EdgeInsets.zero,
                  child: Container(
                    height: AppSpacing.iconTarget,
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
                        // Clear-text button, only visible when there's text.
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
                                width: AppSpacing.iconTarget,
                                height: AppSpacing.iconTarget,
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
                : Text(
                  'Pals',
                  style: AppTextStyles.headingText.copyWith(
                    color: textTheme,
                    fontSize: 20,
                  ),
                ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          if (_isSearching)
            // Cancel search.
            AppChrome.iconAction(
              icon: Icons.close,
              tooltip: 'Cancel search',
              color: textTheme,
              onPressed: _stopSearch,
            )
          else ...[
            // Start search.
            AppChrome.iconAction(
              icon: CupertinoIcons.search,
              tooltip: 'Search pals',
              color: textTheme,
              onPressed: _startSearch,
            ),
            // Filter button with a small dot when a filter is active.
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppChrome.iconAction(
                  icon: Icons.tune,
                  tooltip: 'Filter pals',
                  color: textTheme,
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
        ],
      ),
      // Body states: loading -> error -> no pals -> list.
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
                    // Scrollable list of grouped pals.
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: "Your Pals" + count.
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
                            // Shown when search/filter yields no results.
                            if (filtered.isEmpty) _buildEmptyState(textTheme),
                            // One section per letter: header + pal tiles.
                            for (final entry in grouped.entries) ...[
                              Padding(
                                // Key used by _jumpToLetter to scroll here.
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
                    // A-Z quick-jump index on the right.
                    _buildAlphabetIndex(grouped, textTheme),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
    );
  }
}