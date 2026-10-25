import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/services/match_api.dart';

class ExploreExpand extends StatefulWidget {
  final String nodePath;
  final String nodeLabel;

  /// `teach` shows people teaching this skill (Learner mode); `learn` shows
  /// people who want to learn it (Mentor mode).
  final String kind;

  const ExploreExpand({
    super.key,
    required this.nodePath,
    required this.nodeLabel,
    required this.kind,
  });

  @override
  State<ExploreExpand> createState() => _ExploreExpandState();
}

class _ExploreExpandState extends State<ExploreExpand>
    with SingleTickerProviderStateMixin {
  List<Person> _people = const [];
  bool _loading = true;
  String? _error;

  int _currentIndex = 0;
  final List<int> _history = [];
  final List<String?> _historyConnectionIds = [];
  bool _actionInFlight = false;
  bool? _exitRight;

  late final AnimationController _exitController = AnimationController(
    vsync: this,
    duration: AppMotion.exit,
  );

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _animateAdvance(
    Person person, {
    bool right = false,
    String? connectionId,
  }) async {
    if (_exitController.isAnimating) return;
    if (_currentIndex < 0 || _currentIndex >= _people.length) return;
    if (_people[_currentIndex].id != person.id) return;

    _exitRight = right;
    await _exitController.forward(from: 0);
    if (!mounted) return;
    _advanceFrom(person, connectionId: connectionId);
    _exitController.reset();
  }

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentIndex = 0;
      _history.clear();
      _historyConnectionIds.clear();
    });

    try {
      final users = await MatchApi.browseSkillUsers(
        widget.nodePath,
        kind: widget.kind,
      );

      final seen = <String>{};
      final unique = users.where((u) => seen.add(u.id)).toList();

      if (!mounted) return;

      setState(() {
        _people = unique;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _next({String? connectionId}) {
    if (_currentIndex >= _people.length) return;

    setState(() {
      _history.add(_currentIndex);
      _historyConnectionIds.add(connectionId);
      _currentIndex++;
    });
  }

  /// Advance only if [person] is still the visible card. This makes a late
  /// swipe/dismiss callback and a button callback idempotent for one card.
  void _advanceFrom(Person person, {String? connectionId}) {
    if (!mounted) return;
    if (_currentIndex < 0 || _currentIndex >= _people.length) return;
    if (_people[_currentIndex].id != person.id) return;
    _next(connectionId: connectionId);
  }

  Future<void> _undo() async {
    if (_history.isEmpty) return;

    final index = _history.last;
    final connectionId = _historyConnectionIds.last;
    if (connectionId != null) {
      try {
        await MatchApi.cancelConnectionRequest(connectionId);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not withdraw request: $e')),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _history.removeLast();
      _historyConnectionIds.removeLast();
      _currentIndex = index;
    });
  }

  Future<void> _sendSwipeRequest(Person person) async {
    if (_actionInFlight) return;
    _actionInFlight = true;
    try {
      final connectionId = await MatchApi.sendConnectionRequest(person.id);
      if (!mounted) return;
      _advanceFrom(person, connectionId: connectionId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request sent to ${person.name}'),
          action: SnackBarAction(label: 'Undo', onPressed: _undo),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request failed: $e')));
      _loadPeople();
    } finally {
      _actionInFlight = false;
    }
  }

  Future<void> _confirmAdd(Person person) async {
    if (_actionInFlight) return;
    _actionInFlight = true;

    try {
      final connectionId = await MatchApi.sendConnectionRequest(person.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request sent to ${person.name}'),
          action: SnackBarAction(label: 'Undo', onPressed: _undo),
        ),
      );
      await _animateAdvance(person, right: true, connectionId: connectionId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      _actionInFlight = false;
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
      await _animateAdvance(person);
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
      await _animateAdvance(person);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report failed: $e')));
    } finally {
      _actionInFlight = false;
    }
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
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
              'Nothing more to show',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(28),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Icon(icon, color: color, size: 36),
    );
  }

  Widget _buildDeckCard(Person person) {
    final card = Dismissible(
      key: ValueKey(person.id),
      direction: DismissDirection.horizontal,
      background: _swipeBackground(
        alignment: Alignment.centerLeft,
        color: AppColors.primary,
        icon: Icons.check,
      ),
      secondaryBackground: _swipeBackground(
        alignment: Alignment.centerRight,
        color: AppColors.danger,
        icon: Icons.close,
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _sendSwipeRequest(person);
        } else {
          _advanceFrom(person);
        }
      },
      child: PersonCardOverlay(
        person: person,
        onAdd: () => _confirmAdd(person),
        onSkip: () => _animateAdvance(person),
        onBlock: () => _confirmBlock(person),
        onReport: () => _confirmReport(person),
      ),
    );

    return AnimatedBuilder(
      animation: _exitController,
      child: card,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(_exitController.value);
        if (progress == 0) return child!;
        final cardWidth = MediaQuery.sizeOf(context).width - 32;
        final screenHeight = MediaQuery.sizeOf(context).height;
        final direction = _exitRight == true ? 1.0 : -1.0;
        return IgnorePointer(
          ignoring: true,
          child: Opacity(
            opacity: 1 - progress,
            child: Transform.translate(
              offset: Offset(
                direction * cardWidth * 1.1 * progress,
                screenHeight * 0.35 * progress,
              ),
              child: Transform.rotate(
                angle: direction * 0.22 * progress,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    final hasMore = _currentIndex < _people.length;

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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: textTheme,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                widget.nodeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headingText.copyWith(
                  color: textTheme,
                  fontSize: 18,
                ),
              ),
            ),
            Semantics(
              container: true,
              button: true,
              enabled: _history.isNotEmpty,
              label: 'Undo last person',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _history.isEmpty ? null : _undo,
                child: SizedBox(
                  width: 44,
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
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildErrorState(textTheme)
                  : hasMore
                  ? _buildDeckCard(_people[_currentIndex])
                  : _buildEmptyState(textTheme),
        ),
      ),
    );
  }

  Widget _buildErrorState(Color textTheme2) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Couldn’t load users for ${widget.nodeLabel}.\nPlease check your connection.',
            style: AppTextStyles.regularText.copyWith(color: textTheme2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPeople,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
