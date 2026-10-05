import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/users_dump.dart';

enum ExploreRoleFilter { all, learner, mentor }

class ExploreExpand extends StatefulWidget {
  final SkillCategory category;

  const ExploreExpand({super.key, required this.category});

  @override
  State<ExploreExpand> createState() => _ExploreExpandState();
}

class _ExploreExpandState extends State<ExploreExpand> {
  late final List<Person> _people = dumpUsers
      .where((u) => u.category == widget.category)
      .map((u) => u.toPerson())
      .toList();

  ExploreRoleFilter _roleFilter = ExploreRoleFilter.all;
  int _currentIndex = 0;
  final List<int> _history = [];

  bool get _hasActiveFilter => _roleFilter != ExploreRoleFilter.all;

  List<Person> get _filteredPeople {
    switch (_roleFilter) {
      case ExploreRoleFilter.all:
        return _people;
      case ExploreRoleFilter.learner:
        return _people.where((p) => p.role == PersonRole.learner).toList();
      case ExploreRoleFilter.mentor:
        return _people.where((p) => p.role == PersonRole.mentor).toList();
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

  void _block(String personId) {
    debugPrint('Blocked $personId');
    _next();
  }

  void _report(String personId) {
    debugPrint('Reported $personId');
    _next();
  }

  void _openFilterSheet() {
    ExploreRoleFilter draftRole = _roleFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textColor = Theme.of(context).colorScheme.secondary;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filters',
                            style: AppTextStyles.boldText.copyWith(
                              color: textColor,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setModalState(
                            () => draftRole = ExploreRoleFilter.all,
                          ),
                          child: Text(
                            'Reset',
                            style: AppTextStyles.regularText.copyWith(
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Role',
                      style: AppTextStyles.regularText.copyWith(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip(
                          'All',
                          draftRole == ExploreRoleFilter.all,
                          () => setModalState(
                            () => draftRole = ExploreRoleFilter.all,
                          ),
                          textColor,
                        ),
                        _filterChip(
                          'Learner',
                          draftRole == ExploreRoleFilter.learner,
                          () => setModalState(
                            () => draftRole = ExploreRoleFilter.learner,
                          ),
                          textColor,
                        ),
                        _filterChip(
                          'Mentor',
                          draftRole == ExploreRoleFilter.mentor,
                          () => setModalState(
                            () => draftRole = ExploreRoleFilter.mentor,
                          ),
                          textColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            _roleFilter = draftRole;
                            _currentIndex = 0;
                            _history.clear();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Apply',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : textColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.regularText.copyWith(
            color: isSelected ? Colors.black : textColor,
            fontSize: 13,
          ),
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    final people = _filteredPeople;
    final hasMore = _currentIndex < people.length;

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
                padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: textTheme,
                  size: 16,
                ),
              ),
            ),
            Expanded(
              child: Text(
                widget.category.label,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: _openFilterSheet,
                  icon: Icon(Icons.tune, color: textTheme, size: 24),
                ),
                if (_hasActiveFilter)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          child: hasMore
              ? Dismissible(
                  key: ValueKey(people[_currentIndex].id),
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
                    person: people[_currentIndex],
                    onAdd: _next,
                    onSkip: _next,
                    onBlock: () => _block(people[_currentIndex].id),
                    onReport: () => _report(people[_currentIndex].id),
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'No more people in ${widget.category.label} right now.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}