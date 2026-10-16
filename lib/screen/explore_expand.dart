
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/services/match_api.dart';

class ExploreExpand extends StatefulWidget {
  final String nodePath;
  final String nodeLabel;

  const ExploreExpand({
    super.key,
    required this.nodePath,
    required this.nodeLabel,
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
    });

    try {
      final users = await MatchApi.browseSkillUsers(
        widget.nodePath,
        kind: 'teach',
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

  void _next() {
    setState(() {
      _history.add(_currentIndex);
      _currentIndex++;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;

    setState(() {
      _currentIndex = _history.removeLast();
    });
  }

  Future<void> _confirmBlock(Person person) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Block',
      message:
          '${person.name} won’t be able to find or message you. You can unblock them anytime in Settings.',
      confirmLabel: 'Block',
    );

    if (!confirmed || !mounted) return;

    try {
      await MatchApi.blockUser(person.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You blocked ${person.name}')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Block failed: $e')),
      );
    }

    _next();
  }

  Future<void> _confirmReport(Person person) async {
    final reason = await showReportReasonDialog(
      context,
      name: person.name,
    );

    if (reason == null || !mounted) return;

    try {
      await MatchApi.reportUser(person.id, reason);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your report.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report failed: $e')),
      );
    }

    _next();
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
      child: Icon(
        icon,
        color: color,
        size: 36,
      ),
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.only(
                  right: 12,
                  top: 8,
                  bottom: 8,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: textTheme,
                  size: 16,
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
            IconButton(
              onPressed: _history.isEmpty ? null : _undo,
              icon: Icon(
                CupertinoIcons.arrow_uturn_left,
                color: _history.isEmpty
                    ? textTheme.withValues(alpha: 0.3)
                    : textTheme,
                size: 24,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _error != null
                  ? _buildErrorState(textTheme)
                  : hasMore
                      ? Dismissible(
                          key: ValueKey(_people[_currentIndex].id),
                          direction: DismissDirection.horizontal,
                          background: _swipeBackground(
                            alignment: Alignment.centerLeft,
                            color: AppColors.primary,
                            icon: Icons.check,
                          ),
                          secondaryBackground: _swipeBackground(
                            alignment: Alignment.centerRight,
                            color: Colors.red,
                            icon: Icons.close,
                          ),
                          onDismissed: (_) => _next(),
                          child: PersonCardOverlay(
                            person: _people[_currentIndex],
                            onAdd: null,
                            onSkip: _next,
                            onBlock: () => _confirmBlock(
                              _people[_currentIndex],
                            ),
                            onReport: () => _confirmReport(
                              _people[_currentIndex],
                            ),
                          ),
                        )
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
            style: AppTextStyles.regularText.copyWith(
              color: textTheme2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPeople,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
