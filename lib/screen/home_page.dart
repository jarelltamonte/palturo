import 'dart:async';

import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/card/skills_card.dart' show toTitleCase;
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/explore_deck_page.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_edit.dart';
import 'package:palturo/screen/utils/filter_bottom_sheet.dart';
import 'package:palturo/services/app_navigation.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/notification_service.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/services/seen_deck_service.dart';
import 'package:palturo/widgets/app_feedback.dart';
import 'package:palturo/widgets/app_banner.dart';
import 'package:palturo/widgets/exhausted_deck_view.dart';
import 'package:palturo/widgets/person_card_skeleton.dart';
import 'package:palturo/widgets/swipe_deck.dart';
import 'package:palturo/utils/friendly_error.dart';

enum RoleFilter { all, learner, mentor }

/// How long a cold deck load may look idle before the UI admits it is slow.
@visibleForTesting
const kDeckSlowThreshold = Duration(seconds: 4);

/// Hard cap for a cold deck load. After this the UI offers a retry.
@visibleForTesting
const kDeckTimeout = Duration(seconds: 12);

/// Hard cap for sending a connection request. A hanging request must not leave
/// the deck stuck on its "Sending request…" surface forever.
@visibleForTesting
const kSendRequestTimeout = Duration(seconds: 12);

typedef SendConnectionRequest =
    Future<String?> Function(
      String userId, {
      String? skillName,
      String? skillPath,
    });

/// Sends a request with a hard cap so a stalled network call cannot leave the
/// deck on its busy surface forever.
@visibleForTesting
Future<String?> sendRequestWithTimeout(
  SendConnectionRequest send,
  Person person, {
  Duration timeout = kSendRequestTimeout,
}) => send(
  person.id,
  skillName: person.skillName,
  skillPath: person.skillPath,
).timeout(timeout);

class HomePage extends StatefulWidget {
  /// Test hook: replaces the real deck fetch. Production leaves this null.
  final Future<List<Person>> Function({bool force})? deckLoader;

  /// Test hook: replaces the real request send. Production leaves this null.
  final SendConnectionRequest? sendRequest;

  /// Test hook: replaces the persisted seen set. Production leaves this null.
  final Future<Set<String>> Function()? seenLoader;

  /// Test hook: replaces the persisted seen writes. Production leaves these null.
  final Future<void> Function(String personId)? markSeen;
  final Future<void> Function(String personId)? unmarkSeen;

  /// Switches the shell to Browse. Null when HomePage is used standalone.
  final VoidCallback? onBrowse;

  const HomePage({
    super.key,
    this.deckLoader,
    this.sendRequest,
    this.seenLoader,
    this.markSeen,
    this.unmarkSeen,
    this.onBrowse,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Person> _people = const [];
  List<Person> _rawDeck = const [];
  bool _replayAll = false;
  bool _loading = true;
  bool _slowLoad = false;
  Timer? _slowTimer;
  Timer? _timeoutTimer;
  String? _error;
  ProfileData? _myProfile;
  bool _profileNudgeShown = false;

  RoleFilter _roleFilter = RoleFilter.all;
  String _skillFilter = 'all';
  int _currentIndex = 0;
  final List<int> _history = [];
  final List<bool> _historyRight = [];
  final List<String?> _historyConnectionIds = [];
  bool _undoActive = false;
  bool _undoRight = false;
  bool _undoing = false;
  int _undoToken = 0;
  bool _openingEditor = false;
  bool _actionInFlight = false;
  bool _sendingRequest = false;
  int _deckGeneration = 0;
  final GlobalKey<SwipeDeckState> _swipeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<Set<String>> _loadSeen() async {
    try {
      final loader = widget.seenLoader ?? SeenDeckService.instance.load;
      return await loader();
    } catch (_) {
      return <String>{};
    }
  }

  List<Person> _visibleDeck(List<Person> deck, Set<String> seen) {
    if (_replayAll) return List<Person>.of(deck);
    return deck
        .where((person) => !seen.contains(person.id))
        .toList(growable: false);
  }

  Future<void> _loadDeck({bool force = false}) async {
    final generation = ++_deckGeneration;

    _slowTimer?.cancel();
    _slowTimer = null;
    _timeoutTimer?.cancel();

    // Arm the slow-state timer when the load starts, not after the local
    // seen read, so the 4s promise still holds on a cold open.
    if (_loading) {
      _slowTimer = Timer(kDeckSlowThreshold, () {
        if (mounted && _loading) setState(() => _slowLoad = true);
      });
    }

    // Read the local seen set before painting the cached deck so a relogin
    // never flashes cards that are already exhausted.
    final seen = await _loadSeen();
    if (!mounted || generation != _deckGeneration) return;

    final cached = _cachedDeck();
    setState(() {
      if (_people.isEmpty && cached != null) {
        _people = _visibleDeck(cached, seen);
        _currentIndex = 0;
      }
      _loading = _people.isEmpty;
      _slowLoad = false;
      _error = null;
    });

    // A retry from the error state starts with _loading false, so the cold
    // timer above was skipped. Arm it now that the load is actually running.
    if (_loading && _slowTimer == null) {
      _slowTimer = Timer(kDeckSlowThreshold, () {
        if (mounted && _loading) setState(() => _slowLoad = true);
      });
    }

    try {
      final result = Completer<List<Person>>();
      _timeoutTimer = Timer(kDeckTimeout, () {
        if (!result.isCompleted) {
          result.completeError(TimeoutException('deck load timed out'));
        }
      });
      unawaited(
        _fetchDeck(force: force).then(
          (deck) {
            if (!result.isCompleted) result.complete(deck);
          },
          onError: (Object error, StackTrace stack) {
            if (!result.isCompleted) result.completeError(error, stack);
          },
        ),
      );

      final deck = await result.future;
      if (!mounted || generation != _deckGeneration) return;
      _timeoutTimer?.cancel();
      _slowTimer?.cancel();
      debugPrint('[People] deck loaded: ${deck.length} people');

      setState(() {
        final sameDeck = _sameDeck(_rawDeck, deck);
        _rawDeck = deck;
        _people = _visibleDeck(deck, seen);
        _loading = false;
        _slowLoad = false;
        if (!sameDeck) {
          _currentIndex = 0;
          _history.clear();
          _historyRight.clear();
          _historyConnectionIds.clear();
          _undoActive = false;
        } else if (_currentIndex > _people.length) {
          _currentIndex = _people.length;
        }
        if (_skillFilter != 'all' &&
            !_people.any((person) => person.skillName == _skillFilter)) {
          _skillFilter = 'all';
        }
      });
    } on TimeoutException {
      if (!mounted || generation != _deckGeneration) return;
      _slowTimer?.cancel();
      _timeoutTimer?.cancel();
      setState(() {
        _error =
            'This is taking longer than expected. Check your connection and try again.';
        _loading = false;
        _slowLoad = false;
      });
    } catch (e, st) {
      if (!mounted || generation != _deckGeneration) return;
      _slowTimer?.cancel();
      _timeoutTimer?.cancel();
      debugPrint('[People] _loadDeck ERROR: $e\n$st');

      setState(() {
        _error = friendlyError(
          e,
          fallback: "Couldn't load recommendations. Please try again.",
        );
        _loading = false;
        _slowLoad = false;
      });
    }
  }

  String get _roleKey => switch (_roleFilter) {
    RoleFilter.learner => 'learner',
    RoleFilter.mentor => 'mentor',
    RoleFilter.all => 'all',
  };

  /// Cached deck for the current filter, if one is already in memory. This
  /// paints the previous deck instantly on a cold open instead of flashing an
  /// empty state while the profile and network calls settle.
  List<Person>? _cachedDeck() {
    if (widget.deckLoader != null) return null;
    if (_roleFilter == RoleFilter.all) {
      final learner = MatchApi.peekDeck('learner');
      final mentor = MatchApi.peekDeck('mentor');
      if (learner == null || mentor == null) return null;
      return _mergeDecks([learner, mentor]);
    }
    return MatchApi.peekDeck(_roleKey);
  }

  bool _sameDeck(List<Person> a, List<Person> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  List<Person> _mergeDecks(Iterable<List<Person>> decks) {
    final byId = <String, Person>{};
    for (final person in decks.expand((deck) => deck)) {
      final existing = byId[person.id];
      if (existing == null ||
          (person.compatibility ?? 0) > (existing.compatibility ?? 0)) {
        byId[person.id] = person;
      }
    }
    return byId.values.toList()
      ..sort((a, b) => (b.compatibility ?? 0).compareTo(a.compatibility ?? 0));
  }

  Future<List<Person>> _fetchDeck({bool force = false}) async {
    if (widget.deckLoader != null) return widget.deckLoader!(force: force);

    final me = await ProfileService().getCurrentUserProfile();

    if (mounted && me != null) {
      setState(() => _myProfile = me);
    }

    // No role or no skill means there is nothing to match on yet. Skip the
    // matcher and let For You show the setup checklist instead.
    if (me != null && me.needsSetup) {
      return const [];
    }

    if (_roleFilter == RoleFilter.all) {
      final decks = await Future.wait([
        MatchApi.getMatchDeck(
          asRoleDb: 'learner',
          force: force,
          enrichLimit: 10,
        ),
        MatchApi.getMatchDeck(
          asRoleDb: 'mentor',
          force: force,
          enrichLimit: 10,
        ),
      ]);
      return _mergeDecks(decks);
    }

    return MatchApi.getMatchDeck(
      asRoleDb: _roleKey,
      force: force,
      enrichLimit: 10,
    );
  }

  void _confirmAdd(Person person) {
    if (_actionInFlight || _sendingRequest || _undoing) return;
    // The request is committed by _handleSwiped after the card exits, so the
    // button and a right swipe share exactly one network path.
    _dismissCard(person, right: true);
  }

  Future<void> _openSettings() async {
    if (_openingEditor) return;
    _openingEditor = true;

    try {
      var profile = _myProfile;

      // Never open the editor with a placeholder: the editor writes every
      // field it shows, so a failed load must not become a save of fake data.
      if (profile == null) {
        final fetched = await ProfileService().getCurrentUserProfile();
        if (!mounted) return;
        if (fetched == null) {
          showAppError(
            context,
            'Couldn’t load your profile. Please try again.',
          );
          return;
        }
        profile = fetched;
        setState(() => _myProfile = fetched);
      }

      final seed = profile;
      final updated = await Navigator.push<ProfileData>(
        context,
        MaterialPageRoute(builder: (context) => ProfileEditPage(profile: seed)),
      );

      if (!mounted) return;
      if (updated != null) {
        setState(() => _myProfile = updated);
      }
    } finally {
      _openingEditor = false;
    }
  }

  bool get _hasActiveFilter =>
      _roleFilter != RoleFilter.all || _skillFilter != 'all';

  List<Person> get _filteredPeople {
    if (_skillFilter == 'all') return _people;
    return _people
        .where((person) => person.skillName == _skillFilter)
        .toList(growable: false);
  }

  List<FilterSection> get _filterSections {
    final skills =
        _people
            .map((person) => person.skillName.trim())
            .where((skill) => skill.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return [
      const FilterSection(
        key: 'role',
        title: 'Show',
        options: [
          FilterOption('All roles', 'all'),
          FilterOption('Learners', 'learner'),
          FilterOption('Mentors', 'mentor'),
        ],
      ),
      if (skills.isNotEmpty)
        FilterSection(
          key: 'skill',
          title: 'Skill',
          options: [
            const FilterOption('All skills', 'all'),
            for (final skill in skills) FilterOption(toTitleCase(skill), skill),
          ],
        ),
    ];
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      sections: _filterSections,
      selected: {'role': _roleFilter.name, 'skill': _skillFilter},
      onApply: (result) {
        final newRole = RoleFilter.values.firstWhere(
          (r) => r.name == result['role'],
          orElse: () => RoleFilter.all,
        );
        final newSkill = result['skill'] ?? 'all';
        final roleChanged = newRole != _roleFilter;

        setState(() {
          _roleFilter = newRole;
          _skillFilter = newSkill;
          _replayAll = false;
          if (roleChanged) _people = const [];
          _currentIndex = 0;
          _history.clear();
          _historyRight.clear();
          _historyConnectionIds.clear();
          _undoActive = false;
        });

        if (roleChanged) _loadDeck();
      },
    );
  }

  void _next({bool right = false, String? connectionId}) {
    if (_currentIndex >= _filteredPeople.length || _undoing) return;

    setState(() {
      _history.add(_currentIndex);
      _historyRight.add(right);
      _historyConnectionIds.add(connectionId);
      _undoActive = false;
      _currentIndex++;
    });
  }

  /// Advance only if [person] is still the card on screen. A swipe animation
  /// and a button/request callback can otherwise both advance the same card.
  void _advanceFrom(Person person, {bool right = false, String? connectionId}) {
    if (!mounted) return;
    final people = _filteredPeople;
    if (_currentIndex < 0 || _currentIndex >= people.length) return;
    if (people[_currentIndex].id != person.id) return;
    final before = _currentIndex;
    _next(right: right, connectionId: connectionId);
    if (_currentIndex == before) return;
    final mark = widget.markSeen ?? SeenDeckService.instance.markSeen;
    unawaited(mark(person.id));
  }

  /// A right swipe and the Connect button both land here. The request is the
  /// commit action: failure restores the card instead of pretending success.
  Future<void> _handleSwiped(Person person, bool right) async {
    if (!right) {
      _advanceFrom(person);
      return;
    }
    if (_actionInFlight || _undoing) {
      _resetCard();
      return;
    }

    _actionInFlight = true;
    setState(() => _sendingRequest = true);
    try {
      final send = widget.sendRequest ?? MatchApi.sendConnectionRequest;
      final connectionId = await sendRequestWithTimeout(send, person);
      if (!mounted) return;
      if (connectionId == null || connectionId.isEmpty) {
        throw Exception('The server did not confirm the request.');
      }
      _advanceFrom(person, right: true, connectionId: connectionId);
      Haptics.success();
      showAppSuccess(context, 'Connection request sent to ${person.name}');
      unawaited(_maybeShowProfileNudge());
    } on TimeoutException {
      if (!mounted) return;
      Haptics.error();
      _resetCard();
      showAppError(
        context,
        'Sending the request took too long. Check your connection and try again.',
      );
    } catch (e) {
      if (!mounted) return;
      Haptics.error();
      _resetCard();
      showAppError(
        context,
        friendlyError(
          e,
          fallback: 'Could not send this request. Please try again.',
        ),
      );
    } finally {
      _actionInFlight = false;
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Future<void> _maybeShowProfileNudge() async {
    if (_profileNudgeShown) return;
    final profile = _myProfile;
    if (profile == null || profile.isProfileCompleted) return;
    _profileNudgeShown = true;
    final needsShowcase = profile.needsShowcase;
    AppBannerController.instance.show(
      AppBannerData(
        id: 'profile-nudge',
        title: needsShowcase ? 'Add a showcase' : 'Finish your profile',
        body:
            needsShowcase
                ? 'A showcase is what people see on your card. Add one so '
                    'you appear in For You and Browse.'
                : 'Add a photo, bio, and languages so Pals can match with you.',
        icon: Icons.auto_awesome_outlined,
        actionLabel: needsShowcase ? 'Add showcase' : 'Complete profile',
        onAction: _openSettings,
        duration: const Duration(seconds: 10),
      ),
    );
  }

  void _resetCard() {
    if (!mounted) return;
    _swipeKey.currentState?.reset();
  }

  void _dismissCard(Person person, {bool right = false}) {
    final people = _filteredPeople;
    if (_currentIndex < 0 || _currentIndex >= people.length) return;
    if (people[_currentIndex].id != person.id) return;

    final state = _swipeKey.currentState;
    if (state == null || state.widget.cardKey != person.id) {
      _handleSwiped(person, right);
      return;
    }
    state.dismiss(right: right);
  }

  Future<void> _undo() async {
    if (_history.isEmpty || _undoing || _sendingRequest) return;

    final index = _history.last;
    final right = _historyRight.last;
    final connectionId = _historyConnectionIds.last;

    if (right && connectionId != null) {
      _undoing = true;
      try {
        await MatchApi.cancelConnectionRequest(connectionId);
      } catch (e) {
        if (!mounted) return;
        _undoing = false;
        showAppError(
          context,
          friendlyError(
            e,
            fallback: 'Could not withdraw this request. Please try again.',
          ),
        );
        return;
      }
      _undoing = false;
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      showAppSnackBar(context, 'Connection request withdrawn');
    }

    if (!mounted) return;
    Haptics.selection();
    setState(() {
      _history.removeLast();
      _historyRight.removeLast();
      _historyConnectionIds.removeLast();
      _currentIndex = index;
      _undoRight = right;
      _undoActive = true;
      _undoToken++;
    });

    final people = _filteredPeople;
    if (index >= 0 && index < people.length) {
      final unmark = widget.unmarkSeen ?? SeenDeckService.instance.unmarkSeen;
      unawaited(unmark(people[index].id));
    }
  }

  Widget _wrapUndo(Widget child) {
    if (!_undoActive) return child;

    final size = MediaQuery.of(context).size;
    final travelWidth = size.width > 600 ? 460.0 : size.width;
    final dir = _undoRight ? 1.0 : -1.0;

    return TweenAnimationBuilder<double>(
      key: ValueKey('undo$_undoToken'),
      tween: Tween(begin: 1.0, end: 0.0),
      duration: AppMotion.feedback,
      curve: Curves.easeOutCubic,
      child: child,
      builder:
          (context, v, child) => Opacity(
            opacity: 1 - v * 0.5,
            child: Transform.translate(
              offset: Offset(
                dir * v * travelWidth * 0.7,
                v * size.height * 0.35,
              ),
              child: Transform.rotate(angle: dir * v * 0.25, child: child),
            ),
          ),
    );
  }

  Widget _buildDeck(List<Person> people) {
    final current = people[_currentIndex];

    return _wrapUndo(
      SwipeDeck(
        key: _swipeKey,
        cardKey: current.id,
        enabled: !_sendingRequest,
        busy: _sendingRequest,
        rightLabel: 'Send request',
        leftLabel: 'Skip',
        onSwiped: (right) => _handleSwiped(current, right),
        child: PersonCardOverlay(
          person: current,
          addLabel: 'Send request',
          onAdd: () => _confirmAdd(current),
          onSkip: () => _dismissCard(current),
          onBlock: () => _confirmBlock(current),
          onReport: () => _confirmReport(current),
          onOpenProfile: () => _openProfile(current),
          showProfilePill: false,
          showShadow: false,
          showSkillNote: true,
        ),
      ),
    );
  }

  void _openProfile(Person person) {
    showPersonProfileDialog(
      context,
      person,
      onBlock: () => _confirmBlock(person),
      onReport: (reason) => _confirmReport(person),
    );
  }

  void _openExploreDeck() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExploreDeckPage()),
    );
  }

  /// Replays the cards already fetched for this session. The persisted seen
  /// set is left intact so the next relogin still opens on the exhausted view.
  void _viewAgain() {
    if (_rawDeck.isEmpty) {
      _loadDeck(force: true);
      return;
    }
    Haptics.selection();
    setState(() {
      _replayAll = true;
      _people = List<Person>.of(_rawDeck);
      _currentIndex = 0;
      _history.clear();
      _historyRight.clear();
      _historyConnectionIds.clear();
      _undoActive = false;
    });
  }

  Future<void> _confirmBlock(Person person) async {
    if (_actionInFlight) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Block',
      message:
          '${person.name} won’t be able to find or message you. You can unblock them anytime in Settings.',
      confirmLabel: 'Block',
    );

    if (!confirmed || !mounted) return;

    _actionInFlight = true;
    try {
      await MatchApi.blockUser(person.id);
      await ChatStateService.instance.loadConversations(showSpinner: false);

      if (!mounted) return;

      showAppSuccess(context, 'You blocked ${person.name}');
      _dismissCard(person);
    } catch (e) {
      if (!mounted) return;

      showAppError(
        context,
        friendlyError(
          e,
          fallback: 'Could not block this person. Please try again.',
        ),
      );
    } finally {
      _actionInFlight = false;
    }
  }

  Future<void> _confirmReport(Person person) async {
    if (_actionInFlight) return;

    final reason = await showReportReasonDialog(context, name: person.name);

    if (reason == null || !mounted) return;

    _actionInFlight = true;
    try {
      await MatchApi.reportUser(person.id, reason);

      if (!mounted) return;

      showAppSuccess(context, 'Thanks for your report.');
      _dismissCard(person);
    } catch (e) {
      if (!mounted) return;

      showAppError(
        context,
        friendlyError(
          e,
          fallback: 'Could not send this report. Please try again.',
        ),
      );
    } finally {
      _actionInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    final people = _filteredPeople;
    final hasMore = _currentIndex < people.length;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final desktop = MediaQuery.sizeOf(context).width >= 900;

    final content =
        _loading
            ? _buildLoadingState()
            : _error != null && _people.isEmpty
            ? _buildErrorState(textTheme)
            : hasMore
            ? _buildDeck(people)
            : _buildExhaustedState();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: AppSpacing.topBarHeight(),
        backgroundColor: Colors.transparent,
        titleSpacing: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.only(
            left: desktop ? AppSpacing.titleSpacing : AppSpacing.pageHorizontal,
            right: (16.0 - (AppSpacing.iconTarget - 24) / 2).clamp(0.0, 16.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (desktop)
                Text(
                  'For You',
                  style: AppTextStyles.headingText.copyWith(color: textTheme),
                )
              else
                Transform.translate(
                  offset: const Offset(-10, 0),
                  child: Image.asset(
                    isDarkMode
                        ? 'assets/images/hlogo_white.png'
                        : 'assets/images/hlogo_black.png',
                    height: 40,
                  ),
                ),
              Row(
                children: [
                  ListenableBuilder(
                    listenable: NotificationService.instance,
                    builder: (context, _) {
                      final unread =
                          PreferencesService.instance.notificationsEnabled
                              ? NotificationService.instance.unread
                              : 0;
                      final label =
                          unread > 0 ? 'Activity, $unread unread' : 'Activity';
                      return Semantics(
                        button: true,
                        label: label,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => AppRouter.openActivity(),
                          child: SizedBox(
                            width: AppSpacing.iconTarget,
                            height: AppSpacing.iconTarget,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.notifications_none_rounded,
                                    color: textTheme,
                                    size: 24,
                                  ),
                                ),
                                if (unread > 0)
                                  Positioned(
                                    right: -2,
                                    top: 8,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                      ),
                                      height: 16,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        unread > 99 ? '99+' : '$unread',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Semantics(
                    button: true,
                    enabled: _history.isNotEmpty,
                    label: 'Undo last person',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap:
                          _history.isEmpty || _sendingRequest || _undoing
                              ? null
                              : _undo,
                      child: SizedBox(
                        width: AppSpacing.iconTarget,
                        height: AppSpacing.iconTarget,
                        child: Align(
                          alignment: Alignment.center,
                          child: Icon(
                            CupertinoIcons.arrow_uturn_left,
                            color:
                                _history.isEmpty || _sendingRequest || _undoing
                                    ? textTheme.withValues(alpha: 0.3)
                                    : textTheme,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Filter recommendations',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openFilterSheet,
                      child: SizedBox(
                        width: AppSpacing.iconTarget,
                        height: AppSpacing.iconTarget,
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
                                right: -2,
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
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          desktop
              ? 24
              : MediaQuery.textScalerOf(context).scale(12) > 16
              ? 112
              : 90,
        ),
        child:
            desktop
                ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: content,
                  ),
                )
                : content,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const PersonCardSkeleton(),
        if (_slowLoad)
          Positioned(
            left: AppSpacing.pageHorizontal,
            right: AppSpacing.pageHorizontal,
            bottom: 16,
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Still looking for matches…',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.regularText.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _loadDeck(force: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState(Color textColor) {
    final raw =
        (_error ?? '').replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    final message =
        raw.isEmpty ? "Couldn't load recommendations. Please try again." : raw;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: AppTextStyles.regularText.copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDeck,
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
      ),
    );
  }

  Widget _buildExhaustedState() {
    final needsSetup = _myProfile?.needsSetup ?? false;
    return ExhaustedDeckView(
      onExplore: _openExploreDeck,
      onViewAgain: _viewAgain,
      onBrowse: widget.onBrowse,
      onUpdateProfile: _openSettings,
      message:
          needsSetup
              ? 'Complete your profile setup so we can find Pals for you. '
                  'Add a role and at least one skill.'
              : ExhaustedDeckView.note,
      showViewAgain: !needsSetup,
      showBrowse: !needsSetup,
    );
  }
}
