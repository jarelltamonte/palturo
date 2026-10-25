import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/card/skills_card.dart' show toTitleCase;
import 'package:palturo/screen/utils/schedule_format.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_edit.dart';
import 'package:palturo/screen/utils/filter_bottom_sheet.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/widgets/person_card_skeleton.dart';

enum RoleFilter { all, learner, mentor }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Person> _people = const [];
  bool _loading = true;
  String? _error;
  ProfileData? _myProfile;

  late final TapGestureRecognizer _settingsTap =
      TapGestureRecognizer()..onTap = _openSettings;

  static const List<FilterSection> _filterSections = [
    FilterSection(
      key: 'role',
      title: 'Role',
      options: [
        FilterOption('All', 'all'),
        FilterOption('Learner', 'learner'),
        FilterOption('Mentor', 'mentor'),
      ],
    ),
  ];

  RoleFilter _roleFilter = RoleFilter.all;
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
  double _dragProgress = 0;
  bool _discovering = false;
  int _deckGeneration = 0;
  final GlobalKey<_SwipeableCardState> _swipeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  Future<void> _loadDeck({bool force = false}) async {
    final cached = MatchApi.hasCachedDeck(_roleKey);
    final generation = ++_deckGeneration;

    setState(() {
      _loading = !cached && _people.isEmpty;
      _error = null;
      _discovering = false;
    });

    try {
      final deck = await _fetchDeck(force: force);
      debugPrint('[People] deck loaded: ${deck.length} people');

      if (!mounted || generation != _deckGeneration) return;

      setState(() {
        _people = deck;
        _loading = false;
        _currentIndex = 0;
        _history.clear();
        _historyRight.clear();
        _historyConnectionIds.clear();
        _undoActive = false;
      });
    } catch (e, st) {
      debugPrint('[People] _loadDeck ERROR: $e\n$st');

      if (!mounted || generation != _deckGeneration) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String get _roleKey => switch (_roleFilter) {
    RoleFilter.learner => 'learner',
    RoleFilter.mentor => 'mentor',
    RoleFilter.all => _oppositeRoleKey,
  };

  String get _oppositeRoleKey {
    final role = _myProfile?.role;
    return role == OnboardingRole.teach ? 'learner' : 'mentor';
  }

  Future<List<Person>> _fetchDeck({bool force = false}) async {
    final me = await ProfileService().getCurrentUserProfile();

    if (mounted && me != null) {
      setState(() => _myProfile = me);
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

  @override
  void dispose() {
    _settingsTap.dispose();
    super.dispose();
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Couldn’t load your profile. Please try again.'),
            ),
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

  bool get _hasActiveFilter => _roleFilter != RoleFilter.all;

  List<Person> get _filteredPeople => _people;

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      sections: _filterSections,
      selected: {'role': _roleFilter.name},
      onApply: (result) {
        final newRole = RoleFilter.values.firstWhere(
          (r) => r.name == result['role'],
          orElse: () => RoleFilter.all,
        );

        if (newRole != _roleFilter) {
          setState(() {
            _roleFilter = newRole;
            _currentIndex = 0;
            _history.clear();
            _historyRight.clear();
            _historyConnectionIds.clear();
            _undoActive = false;
          });

          _loadDeck();
        }
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
      _dragProgress = 0;
    });
  }

  /// Advance only if [person] is still the card on screen. A swipe animation
  /// and a button/request callback can otherwise both advance the same card.
  void _advanceFrom(Person person, {bool right = false, String? connectionId}) {
    if (!mounted) return;
    final people = _filteredPeople;
    if (_currentIndex < 0 || _currentIndex >= people.length) return;
    if (people[_currentIndex].id != person.id) return;
    _next(right: right, connectionId: connectionId);
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
      final connectionId = await MatchApi.sendConnectionRequest(person.id);
      if (!mounted) return;
      if (connectionId == null || connectionId.isEmpty) {
        throw Exception('The server did not confirm the request.');
      }
      _advanceFrom(person, right: true, connectionId: connectionId);
      Haptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request sent to ${person.name}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undoRequest(connectionId),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _resetCard();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: ${_cleanError(e)}')),
      );
    } finally {
      _actionInFlight = false;
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  void _resetCard() {
    if (!mounted) return;
    setState(() => _dragProgress = 0);
    _swipeKey.currentState?.reset();
  }

  void _dismissCard(Person person, {bool right = false}) {
    final people = _filteredPeople;
    if (_currentIndex < 0 || _currentIndex >= people.length) return;
    if (people[_currentIndex].id != person.id) return;

    final state = _swipeKey.currentState;
    if (state == null || state.widget.personId != person.id) {
      _handleSwiped(person, right);
      return;
    }
    state.dismiss(right: right);
  }

  Future<void> _undoRequest(String connectionId) async {
    if (_historyConnectionIds.isEmpty ||
        _historyConnectionIds.last != connectionId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That request is no longer the latest action.'),
        ),
      );
      return;
    }
    await _undo();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not withdraw request: ${_cleanError(e)}'),
          ),
        );
        return;
      }
      _undoing = false;
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection request withdrawn')),
      );
    }

    if (!mounted) return;
    setState(() {
      _history.removeLast();
      _historyRight.removeLast();
      _historyConnectionIds.removeLast();
      _currentIndex = index;
      _undoRight = right;
      _undoActive = true;
      _undoToken++;
    });
  }

  Widget _wrapUndo(Widget child) {
    if (!_undoActive) return child;

    final size = MediaQuery.of(context).size;
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
                dir * v * size.width * 0.7,
                v * size.height * 0.35,
              ),
              child: Transform.rotate(angle: dir * v * 0.25, child: child),
            ),
          ),
    );
  }

  Widget _buildDeckCard(Person person) {
    return _wrapUndo(
      _SwipeableCard(
        key: _swipeKey,
        personId: person.id,
        onSwiped: (right) => _handleSwiped(person, right),
        onDragProgress: (value) {
          if ((value - _dragProgress).abs() > 0.01) {
            setState(() => _dragProgress = value);
          }
        },
        child: PersonCardOverlay(
          person: person,
          onAdd: () => _confirmAdd(person),
          onSkip: () => _dismissCard(person),
          onBlock: () => _confirmBlock(person),
          onReport: () => _confirmReport(person),
          onOpenProfile: () => _openProfile(person),
          onWhyMatch:
              person.compatibility == null ? null : () => _showWhyMatch(person),
        ),
      ),
    );
  }

  Widget _buildDeck(List<Person> people) {
    final current = people[_currentIndex];
    final next =
        _currentIndex + 1 < people.length ? people[_currentIndex + 1] : null;
    final progress = _dragProgress.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (next != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.scale(
                scale: 0.97 + (0.03 * progress),
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - progress)),
                  child: Opacity(
                    opacity: 0.55 + (0.45 * progress),
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: reduceMotion ? 0 : 3 * (1 - progress),
                        sigmaY: reduceMotion ? 0 : 3 * (1 - progress),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: ExcludeSemantics(
                          child: PersonCardOverlay(
                            person: next,
                            showActions: false,
                            showMenu: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(
            bottom: next == null ? 0 : 26 * (1 - progress),
          ),
          child: _buildDeckCard(current),
        ),
        if (next != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 3,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 210),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(
                      context,
                    ).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Text(
                    'Up next · ${next.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.mutedText(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_sendingRequest)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sending request…',
                          style: AppTextStyles.boldText.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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

  Future<void> _showWhyMatch(Person person) async {
    final score = (((person.compatibility ?? 0) * 100).clamp(0, 100)).round();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevatedSurface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (sheetContext) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Why this match?',
                            style: AppTextStyles.headingText.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        Text(
                          '$score%',
                          style: AppTextStyles.headingText.copyWith(
                            color: AppColors.accentText(context),
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      person.pipeline == 'basic_bi'
                          ? 'This result uses basic profile similarity because the full reciprocal reranker was unavailable. Treat it as a lighter signal, not a two-way guarantee.'
                          : 'PalTuro compares your learning and teaching profiles in both directions, then weighs the fit. A reciprocal score rewards mutual alignment, not just a one-sided interest.',
                      style: AppTextStyles.regularText.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _MatchFactor(
                      icon: Icons.school_outlined,
                      label: 'Skill',
                      value:
                          person.skillName.trim().isEmpty
                              ? 'Shared skill interest'
                              : toTitleCase(person.skillName),
                    ),
                    _MatchFactor(
                      icon: Icons.translate,
                      label: 'Language',
                      value:
                          person.language.trim().isEmpty
                              ? 'Not specified'
                              : person.language,
                    ),
                    _MatchFactor(
                      icon: Icons.calendar_today_outlined,
                      label: 'Availability',
                      value:
                          person.schedule.trim().isEmpty
                              ? 'Not specified'
                              : formatSchedule(person.schedule),
                    ),
                    _MatchFactor(
                      icon: Icons.psychology_outlined,
                      label: 'Learning style',
                      value:
                          person.learningStyle.trim().isEmpty
                              ? 'Not specified'
                              : person.learningStyle,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('Got it'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _discoverRandom() async {
    if (_discovering) return;

    final generation = _deckGeneration;
    setState(() => _discovering = true);

    try {
      final people = await MatchApi.getRandomDeck(limit: 20, role: _roleKey);

      if (!mounted || generation != _deckGeneration) return;

      final seen = _people.map((person) => person.id).toSet();
      final fresh = people.where((person) => seen.add(person.id)).toList();

      if (fresh.isEmpty) {
        setState(() => _discovering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No more matches to discover right now.'),
          ),
        );
        return;
      }

      setState(() {
        final start = _people.length;
        _people = [..._people, ...fresh];
        _currentIndex = start;
        _undoActive = false;
        _discovering = false;
      });
    } catch (e) {
      debugPrint('[People] _discoverRandom ERROR: $e');
      if (!mounted || generation != _deckGeneration) return;

      setState(() => _discovering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t find more matches. Please try again.'),
        ),
      );
    }
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('You blocked ${person.name}')));
      _dismissCard(person);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Block failed: $e')));
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thanks for your report.')));
      _dismissCard(person);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report failed: $e')));
    } finally {
      _actionInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    final people = _filteredPeople;
    final hasMore = _currentIndex < people.length;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        titleSpacing: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                        width: 44,
                        height: 44,
                        child: Align(
                          alignment: Alignment.centerRight,
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
                        width: 44,
                        height: 44,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child:
            _loading
                ? const PersonCardSkeleton()
                : _error != null
                ? _buildErrorState(textTheme)
                : hasMore
                ? _buildDeck(people)
                : _buildEmptyState(textTheme),
      ),
    );
  }

  Widget _buildErrorState(Color textColor) {
    final raw =
        (_error ?? '').replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    final message =
        raw.contains('Too many deck requests')
            ? raw
            : 'Couldn’t load recommendations.\nPlease check your connection.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return LayoutBuilder(
      builder:
          (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 48)
                          .clamp(0.0, double.infinity)
                          .toDouble(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/lottie/empty.json',
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have seen all the top results',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.regularText.copyWith(
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _discovering ? null : _discoverRandom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      icon:
                          _discovering
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.black,
                                ),
                              )
                              : const Icon(Icons.explore),
                      label: Text(
                        _discovering ? 'Finding matches…' : 'Discover more',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Update your '),
                          TextSpan(
                            text: 'settings',
                            recognizer: _settingsTap,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentText(context),
                              decoration: TextDecoration.underline,
                              decorationThickness: 1.5,
                            ),
                          ),
                        ],
                        style: AppTextStyles.regularText.copyWith(
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

class _MatchFactor extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MatchFactor({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.accentText(context)),
          const SizedBox(width: 10),
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.regularText.copyWith(
                color: textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeableCard extends StatefulWidget {
  final String personId;
  final Widget child;
  final ValueChanged<bool> onSwiped;
  final ValueChanged<double>? onDragProgress;

  const _SwipeableCard({
    super.key,
    required this.personId,
    required this.child,
    required this.onSwiped,
    this.onDragProgress,
  });

  @override
  State<_SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<_SwipeableCard>
    with SingleTickerProviderStateMixin {
  static const double _maxAngle = 0.25;
  static const double _exitFactor = 1.1;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.exit,
  )..addListener(_onTick);

  double _dx = 0;
  double _from = 0;
  double _to = 0;
  double _width = 1;
  bool _exiting = false;

  @override
  void didUpdateWidget(covariant _SwipeableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personId != widget.personId) {
      _controller.stop();
      _dx = 0;
      _from = 0;
      _to = 0;
      _exiting = false;
    }
  }

  void dismiss({bool right = false}) {
    if (_exiting) return;
    _exiting = true;
    _animateTo(
      (right ? 1 : -1) * _width * _exitFactor,
      onDone: () => widget.onSwiped(right),
    );
  }

  /// Restore a card after a failed request or a cancelled gesture.
  void reset() {
    _controller.stop();
    _exiting = false;
    _dx = 0;
    _from = 0;
    _to = 0;
    widget.onDragProgress?.call(0);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    setState(() {
      _dx =
          _from +
          (_to - _from) * Curves.easeOutCubic.transform(_controller.value);
    });
    widget.onDragProgress?.call(
      (_dx.abs() / (_width * _exitFactor)).clamp(0.0, 1.0),
    );
  }

  void _animateTo(double target, {VoidCallback? onDone}) {
    _from = _dx;
    _to = target;

    _controller.forward(from: 0).whenComplete(() {
      if (mounted) onDone?.call();
    });
  }

  void _onDragStart(DragStartDetails d) {
    if (_exiting) return;
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_exiting) return;
    setState(() => _dx += d.delta.dx);
    widget.onDragProgress?.call(
      (_dx.abs() / (_width * _exitFactor)).clamp(0.0, 1.0),
    );
  }

  void _onDragEnd(DragEndDetails d) {
    if (_exiting) return;

    final velocity = d.velocity.pixelsPerSecond.dx;
    final flung = velocity.abs() > 800 && velocity.sign == _dx.sign;
    final passed = _dx.abs() > _width * 0.35 || flung;

    if (!passed) {
      _animateTo(0);
      return;
    }

    final right = _dx > 0;
    _exiting = true;
    Haptics.impact();

    _animateTo(
      (right ? 1 : -1) * _width * _exitFactor,
      onDone: () => widget.onSwiped(right),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final driftRatio = (0.35 * screen.height) / (0.7 * screen.width);

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;

        final angle = (_dx / (_width * 0.7)) * _maxAngle;
        final dy = _dx.abs() * driftRatio;
        final fade = (_dx.abs() / (_width * _exitFactor)).clamp(0.0, 1.0);

        final goingRight = _dx > 0;
        final tint =
            goingRight ? AppColors.primary : AppColors.dangerText(context);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_dx != 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    alignment:
                        goingRight
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Icon(
                      goingRight ? Icons.check : Icons.close,
                      color: tint,
                      size: 36,
                    ),
                  ),
                ),
              Opacity(
                opacity: 1 - fade,
                child: Transform.translate(
                  offset: Offset(_dx, dy),
                  child: Transform.rotate(
                    angle: angle,
                    child: IgnorePointer(
                      ignoring: _exiting,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
