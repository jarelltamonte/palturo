import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/widgets/person_card_skeleton.dart';
import 'package:palturo/utils/friendly_error.dart';

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
  final Map<String, String> _pendingSwipeIds = {};
  bool _actionInFlight = false;
  bool _undoing = false;
  bool _sendingRequest = false;
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
      _pendingSwipeIds.clear();
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
        _error = friendlyError(
          e,
          fallback:
              _error ??
              "Couldn't load users for ${widget.nodeLabel}. Please try again.",
        );
        _loading = false;
      });
    }
  }

  void _next({String? connectionId}) {
    if (_currentIndex >= _people.length || _undoing) return;

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
    if (_history.isEmpty || _undoing || _actionInFlight) return;
    _undoing = true;

    final index = _history.last;
    final connectionId = _historyConnectionIds.last;
    if (connectionId != null) {
      try {
        await MatchApi.cancelConnectionRequest(connectionId);
      } catch (e) {
        _undoing = false;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not withdraw request: $e')),
        );
        return;
      }
    }

    _undoing = false;
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    setState(() {
      _history.removeLast();
      _historyConnectionIds.removeLast();
      _currentIndex = index;
    });
  }

  Future<String?> _sendRequest(Person person) async {
    if (_actionInFlight || _undoing) return null;
    _actionInFlight = true;
    if (mounted) setState(() => _sendingRequest = true);
    try {
      final connectionId = await MatchApi.sendConnectionRequest(person.id);
      if (connectionId == null || connectionId.isEmpty) {
        throw Exception('The server did not confirm the request.');
      }
      Haptics.success();
      return connectionId;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not send request: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
      return null;
    } finally {
      _actionInFlight = false;
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Future<void> _confirmAdd(Person person) async {
    final connectionId = await _sendRequest(person);
    if (!mounted || connectionId == null) return;
    await _animateAdvance(person, right: true, connectionId: connectionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection request sent to ${person.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _undoRequest(connectionId),
        ),
      ),
    );
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
              _people.isEmpty
                  ? 'No people in this category yet.'
                  : 'You’ve seen everyone in this category.',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to category'),
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

  Widget _buildDeck() {
    final current = _people[_currentIndex];
    final next =
        _currentIndex + 1 < _people.length ? _people[_currentIndex + 1] : null;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (next != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.scale(
                scale: 0.97,
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: const Offset(0, 10),
                  child: Opacity(
                    opacity: 0.55,
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
        Padding(
          padding: EdgeInsets.only(bottom: next == null ? 0 : 26),
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
      ],
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
        color: AppColors.dangerText(context),
        icon: Icons.close,
      ),
      confirmDismiss: (direction) async {
        if (direction != DismissDirection.startToEnd) return true;
        final connectionId = await _sendRequest(person);
        if (connectionId == null) return false;
        _pendingSwipeIds[person.id] = connectionId;
        return true;
      },
      onDismissed: (direction) {
        final connectionId = _pendingSwipeIds.remove(person.id);
        _advanceFrom(person, connectionId: connectionId);
        if (direction == DismissDirection.startToEnd) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection request sent to ${person.name}'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => _undoRequest(connectionId ?? ''),
              ),
            ),
          );
        }
      },
      child: PersonCardOverlay(
        person: person,
        onAdd: () => _confirmAdd(person),
        onSkip: () => _animateAdvance(person),
        onBlock: () => _confirmBlock(person),
        onReport: () => _confirmReport(person),
        onOpenProfile: () => showPersonProfileDialog(context, person),
        skipLabel: 'Pass',
        addLabel: 'Send request',
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
                  fontSize: 20,
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
        child: Column(
          children: [
            if (_sendingRequest)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.textScalerOf(context).scale(12) > 16 ? 112 : 90,
                ),
                child:
                    _loading
                        ? const PersonCardSkeleton()
                        : _error != null
                        ? _buildErrorState(textTheme)
                        : hasMore
                        ? _buildDeck()
                        : _buildEmptyState(textTheme),
              ),
            ),
          ],
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
            _error ??
                "Couldn't load users for ${widget.nodeLabel}. Please try again.",
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
