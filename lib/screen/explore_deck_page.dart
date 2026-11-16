import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/utils/friendly_error.dart';
import 'package:palturo/widgets/app_feedback.dart';
import 'package:palturo/widgets/person_card_skeleton.dart';
import 'package:palturo/widgets/swipe_deck.dart';

typedef ExploreDeckLoader = Future<List<Person>> Function({int limit});

/// Endless random card deck reached from the exhausted For You screen.
///
/// Cards look and behave like the For You deck, but the source is random
/// people and the deck refills itself before the user reaches the end.
class ExploreDeckPage extends StatefulWidget {
  const ExploreDeckPage({super.key, this.loader, this.batchSize = 20});

  /// Test hook: replaces the random deck RPC.
  final ExploreDeckLoader? loader;
  final int batchSize;

  @override
  State<ExploreDeckPage> createState() => ExploreDeckPageState();
}

class ExploreDeckPageState extends State<ExploreDeckPage> {
  static const int _prefetchAt = 4;
  static const int _recentLimit = 40;

  List<Person> _people = const [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _loadMoreError;
  int _generation = 0;

  final Set<String> _recentIds = <String>{};
  final List<int> _history = [];
  final List<String?> _historyConnectionIds = [];
  bool _actionInFlight = false;
  bool _undoing = false;
  bool _sendingRequest = false;
  final GlobalKey<SwipeDeckState> _deckKey = GlobalKey();

  /// Test hook: how many cards the deck has buffered so far.
  @visibleForTesting
  int get loadedCount => _people.length;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<List<Person>> _fetch() {
    if (widget.loader != null) return widget.loader!(limit: widget.batchSize);
    return MatchApi.getRandomDeck(limit: widget.batchSize);
  }

  Future<void> _loadInitial() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _loadMoreError = null;
      _people = const [];
      _currentIndex = 0;
      _history.clear();
      _historyConnectionIds.clear();
      _recentIds.clear();
    });

    try {
      final batch = await _fetch();
      if (!mounted || generation != _generation) return;
      final unique = _dedupe(batch, keepCurrent: null);
      setState(() {
        _people = unique;
        _loading = false;
      });
      if (unique.length <= _prefetchAt) {
        unawaited(_loadMore());
      }
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = friendlyError(
          e,
          fallback: "Couldn't load random Pals. Please try again.",
        );
      });
    }
  }

  List<Person> _dedupe(List<Person> batch, {required String? keepCurrent}) {
    final out = <Person>[];
    for (final person in batch) {
      if (person.id == keepCurrent) continue;
      if (_recentIds.add(person.id)) out.add(person);
    }

    // A small community can exhaust the fresh pool. Accept the batch anyway so
    // the deck keeps going instead of stopping.
    if (out.isEmpty) {
      for (final person in batch) {
        if (person.id != keepCurrent) out.add(person);
      }
    }

    if (_recentIds.length > _recentLimit) {
      final keep = _recentIds.toList().sublist(
        _recentIds.length - _recentLimit,
      );
      _recentIds
        ..clear()
        ..addAll(keep);
    }
    return out;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final batch = await _fetch();
      if (!mounted || generation != _generation) return;
      final current =
          _currentIndex < _people.length ? _people[_currentIndex].id : null;
      final fresh = _dedupe(batch, keepCurrent: current);
      if (fresh.isEmpty) {
        setState(() {
          _loadingMore = false;
          _loadMoreError = 'No more random Pals are available right now.';
        });
        return;
      }
      setState(() {
        _people = [..._people, ...fresh];
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = friendlyError(
          e,
          fallback: "Couldn't find more Pals. Please try again.",
        );
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
    if (_currentIndex >= _people.length - _prefetchAt) {
      unawaited(_loadMore());
    }
  }

  /// Advance only if [person] is still the visible card. A late swipe/dismiss
  /// callback and a button callback must not advance the same card twice.
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
          '${person.name} won\u2019t be able to find or message you. You can unblock them anytime in Settings.',
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

  Widget _buildDeck() {
    final current = _people[_currentIndex];
    return SwipeDeck(
      key: _deckKey,
      cardKey: current.id,
      enabled: !_sendingRequest,
      busy: _sendingRequest,
      rightLabel: 'Send request',
      leftLabel: 'Skip',
      onSwiped: (right) => _handleSwipe(current, right),
      child: PersonCardOverlay(
        person: current,
        onAdd: () => _deckKey.currentState?.dismiss(right: true),
        onSkip: () => _deckKey.currentState?.dismiss(right: false),
        onBlock: () => _confirmBlock(current),
        onReport: () => _confirmReport(current),
        onOpenProfile: () => showPersonProfileDialog(context, current),
        skipLabel: 'Skip',
        addLabel: 'Send request',
      ),
    );
  }

  Widget _buildEndState(Color textTheme) {
    if (_loadMoreError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadMoreError!,
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(color: textTheme),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadMore, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    // Normally the prefetch has already added cards. This only shows if the
    // user outruns the network.
    if (!_loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
    }
    return const PersonCardSkeleton();
  }

  Widget _buildEmpty(Color textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No random Pals are available right now.',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitial,
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

  Widget _buildError(Color textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? "Couldn't load random Pals. Please try again.",
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitial,
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final hasMore = _currentIndex < _people.length;

    final content =
        _loading
            ? const PersonCardSkeleton()
            : _error != null && _people.isEmpty
            ? _buildError(textTheme)
            : _people.isEmpty
            ? _buildEmpty(textTheme)
            : hasMore
            ? _buildDeck()
            : _buildEndState(textTheme);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: AppSpacing.topBarHeight(),
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
                'Explore',
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
      ),
    );
  }
}
