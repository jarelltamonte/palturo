import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_edit.dart';
import 'package:palturo/screen/utils/filter_bottom_sheet.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/onboarding/onboarding_models.dart';

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
    FilterSection(key: 'skills', title: 'Skills'),
  ];

  RoleFilter _roleFilter = RoleFilter.all;
  int _currentIndex = 0;
  final List<int> _history = [];
  final List<bool> _historyRight = [];
  bool _undoActive = false;
  bool _undoRight = false;
  int _undoToken = 0;
  bool _openingEditor = false;
  bool _actionInFlight = false;
  bool _discovering = false;
  int _deckGeneration = 0;

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

  Future<void> _confirmAdd(Person person) async {
    if (_actionInFlight) return;
    _actionInFlight = true;

    try {
      await MatchApi.sendConnectionRequest(person.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection request sent to ${person.name}')),
      );
      _advanceFrom(person, right: true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      _actionInFlight = false;
    }
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
            _undoActive = false;
          });

          _loadDeck();
        }
      },
    );
  }

  void _next({bool right = false}) {
    if (_currentIndex >= _filteredPeople.length) return;

    setState(() {
      _history.add(_currentIndex);
      _historyRight.add(right);
      _undoActive = false;
      _currentIndex++;
    });
  }

  /// Advance only if [person] is still the card on screen. A swipe animation
  /// and a button/request callback can otherwise both advance the same card.
  void _advanceFrom(Person person, {bool right = false}) {
    if (!mounted) return;
    final people = _filteredPeople;
    if (_currentIndex < 0 || _currentIndex >= people.length) return;
    if (people[_currentIndex].id != person.id) return;
    _next(right: right);
  }

  void _undo() {
    if (_history.isEmpty) return;

    setState(() {
      _currentIndex = _history.removeLast();
      _undoRight = _historyRight.removeLast();
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
      duration: const Duration(milliseconds: 350),
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
        key: ValueKey(person.id),
        onSwiped: (right) => _advanceFrom(person, right: right),
        child: PersonCardOverlay(
          person: person,
          onAdd: () => _confirmAdd(person),
          onSkip: () => _advanceFrom(person),
          onBlock: () => _confirmBlock(person),
          onReport: () => _confirmReport(person),
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
            content: Text('No more people to discover right now.'),
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
          content: Text('Couldn’t find more people. Please try again.'),
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

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('You blocked ${person.name}')));
      _advanceFrom(person);
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
      _advanceFrom(person);
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _history.isEmpty ? null : _undo,
                    child: SizedBox(
                      width: 40,
                      height: 44,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          CupertinoIcons.arrow_uturn_left,
                          color:
                              _history.isEmpty
                                  ? textTheme.withValues(alpha: 0.3)
                                  : textTheme,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openFilterSheet,
                    child: SizedBox(
                      width: 40,
                      height: 44,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Icon(Icons.tune, color: textTheme, size: 24),
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
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildErrorState(textTheme)
                : hasMore
                ? _buildDeckCard(people[_currentIndex])
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
                      _discovering ? 'Finding people…' : 'Discover more',
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
    );
  }
}

class _SwipeableCard extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool> onSwiped;

  const _SwipeableCard({
    super.key,
    required this.child,
    required this.onSwiped,
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
    duration: const Duration(milliseconds: 280),
  )..addListener(_onTick);

  double _dx = 0;
  double _from = 0;
  double _to = 0;
  double _width = 1;
  bool _exiting = false;

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
        final tint = goingRight ? AppColors.primary : Colors.red;

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
