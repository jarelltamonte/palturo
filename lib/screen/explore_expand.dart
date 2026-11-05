import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/widgets/app_feedback.dart';
import 'package:palturo/widgets/person_card_skeleton.dart';
import 'package:palturo/widgets/swipe_deck.dart';
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

class _ExploreExpandState extends State<ExploreExpand> {
  List<Person> _people = const [];
  bool _loading = true;
  String? _error;

  int _currentIndex = 0;
  final List<int> _history = [];
  final List<String?> _historyConnectionIds = [];
  bool _actionInFlight = false;
  bool _undoing = false;
  bool _sendingRequest = false;
  final GlobalKey<SwipeDeckState> _deckKey = GlobalKey();

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

  void _dismissCard(Person person, {bool right = false}) {
    if (!mounted) return;
    if (_currentIndex < 0 || _currentIndex >= _people.length) return;
    if (_people[_currentIndex].id != person.id) return;
    _deckKey.currentState?.dismiss(right: right);
  }

  Future<void> _handleSwipe(Person person, bool right) async {
    if (!right) {
      _advanceFrom(person);
      return;
    }
    final connectionId = await _sendRequest(person);
    if (!mounted) return;
    if (connectionId == null) {
      _deckKey.currentState?.reset();
      return;
    }
    _advanceFrom(person, connectionId: connectionId);
    showAppSnackBar(
      context,
      'Connection request sent to ${person.name}',
      actionLabel: 'Undo',
      onAction: () => _undoRequest(connectionId),
      duration: const Duration(seconds: 5),
      tone: AppFeedbackTone.success,
    );
  }

  Future<void> _undoRequest(String connectionId) async {
    if (_historyConnectionIds.isEmpty ||
        _historyConnectionIds.last != connectionId) {
      showAppSnackBar(context, 'That request is no longer the latest action.');
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
        showAppError(
          context,
          friendlyError(
            e,
            fallback: 'Could not withdraw this request. Please try again.',
          ),
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
      final connectionId = await MatchApi.sendConnectionRequest(
        person.id,
        skillName: person.skillName,
        skillPath: person.skillPath,
      );
      if (connectionId == null || connectionId.isEmpty) {
        throw Exception('The server did not confirm the request.');
      }
      Haptics.success();
      return connectionId;
    } catch (e) {
      if (mounted) {
        showAppError(
          context,
          friendlyError(
            e,
            fallback: 'Could not send this request. Please try again.',
          ),
        );
      }
      return null;
    } finally {
      _actionInFlight = false;
      if (mounted) setState(() => _sendingRequest = false);
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

      showAppSuccess(context, 'You blocked ${person.name}');
      _dismissCard(person, right: false);
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
      _dismissCard(person, right: false);
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

  Widget _buildDeck() {
    final current = _people[_currentIndex];
    return SwipeDeck(
      key: _deckKey,
      cardKey: current.id,
      enabled: !_sendingRequest,
      busy: _sendingRequest,
      rightLabel: 'Send request',
      leftLabel: 'Pass',
      onSwiped: (right) => _handleSwipe(current, right),
      child: PersonCardOverlay(
        person: current,
        onAdd: () => _deckKey.currentState?.dismiss(right: true),
        onSkip: () => _deckKey.currentState?.dismiss(right: false),
        onBlock: () => _confirmBlock(current),
        onReport: () => _confirmReport(current),
        onOpenProfile: () => showPersonProfileDialog(context, current),
        skipLabel: 'Pass',
        addLabel: 'Send request',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight = AppSpacing.topBarHeight();

    final hasMore = _currentIndex < _people.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.titleSpacing,
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
                  width: AppSpacing.iconTarget,
                  height: AppSpacing.iconTarget,
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
                  width: AppSpacing.iconTarget,
                  height: AppSpacing.iconTarget,
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
