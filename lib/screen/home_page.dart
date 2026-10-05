import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/users_dump.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_edit.dart';

enum RoleFilter { all, learner, mentor }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<Person> _featuredPeople = [
    Person(
      id: '1',
      name: 'RJ Santos',
      schedule: 'Mon/Wed/Sat',
      language: 'English',
      learningStyle: 'Discussion',
      skillName: 'Parol Making',
      role: PersonRole.learner,
      bio: 'Gusto kong matutong gumawa ng parol para sa pamilya ko.',
      photoUrls: [null, null, null],
    ),
    Person(
      id: '2',
      name: 'Maria Dela Cruz',
      schedule: 'Tue/Thu',
      language: 'Tagalog',
      learningStyle: 'Hands-on Practice',
      skillName: 'Weaving Inabel',
      role: PersonRole.mentor,
      bio: 'Lumaki ako sa tabi ng habihan ni Lola. Tuturuan kita nang dahan-dahan.',
      photoUrls: [null],
    ),
    Person(
      id: '3',
      name: 'Jarell Tamonte',
      schedule: 'Mon/Sat/Sun',
      language: 'English, Tagalog',
      learningStyle: 'Visual Demonstration',
      skillName: 'Cooking Pinakbet',
      role: PersonRole.learner,
      bio: 'Gusto kong lutuin ang pinakbet ni Nanay nang eksakto ang timpla.',
      photoUrls: [null, null],
    ),
  ];

  late final List<Person> _people = [
    ..._featuredPeople,
    ...dumpUsers.map(_personFromMatchedUser),
  ];

  static Person _personFromMatchedUser(MatchedUser user) {
    return Person(
      id: 'dump_${user.id}',
      name: user.name,
      schedule: user.schedule,
      language: user.language,
      learningStyle: user.learningStyle,
      skillName: user.skillName,
      role: user.role,
      bio: user.bio,
      photoUrls: [user.avatarUrl],
    );
  }

  static const ProfileData _placeholderProfile = ProfileData(
    name: 'You',
    schedule: 'Select your availability',
  );

  late final TapGestureRecognizer _settingsTap = TapGestureRecognizer()
    ..onTap = _openSettings;

  RoleFilter _roleFilter = RoleFilter.all;
  int _currentIndex = 0;
  final List<int> _history = [];

  @override
  void dispose() {
    _settingsTap.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const ProfileEditPage(profile: _placeholderProfile),
      ),
    );
  }

  bool get _hasActiveFilter => _roleFilter != RoleFilter.all;

  List<Person> get _filteredPeople {
    if (_roleFilter == RoleFilter.all) return _people;
    return _people
        .where((p) =>
            (_roleFilter == RoleFilter.learner &&
                p.role == PersonRole.learner) ||
            (_roleFilter == RoleFilter.mentor && p.role == PersonRole.mentor))
        .toList();
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
    RoleFilter draftRole = _roleFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textColor = Theme.of(context).colorScheme.secondary;
        final primaryColor = AppColors.primary;

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
                          onPressed: () =>
                              setModalState(() => draftRole = RoleFilter.all),
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
                    _sheetSectionLabel('Role', textColor),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip(
                            'All',
                            draftRole == RoleFilter.all,
                            () => setModalState(() => draftRole = RoleFilter.all),
                            primaryColor,
                            textColor),
                        _filterChip(
                            'Learner',
                            draftRole == RoleFilter.learner,
                            () => setModalState(
                                () => draftRole = RoleFilter.learner),
                            primaryColor,
                            textColor),
                        _filterChip(
                            'Mentor',
                            draftRole == RoleFilter.mentor,
                            () => setModalState(
                                () => draftRole = RoleFilter.mentor),
                            primaryColor,
                            textColor),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sheetSectionLabel('Skills', textColor),
                    const SizedBox(height: 8),
                    Text(
                      'Coming soon',
                      style: AppTextStyles.regularText.copyWith(
                        color: textColor.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
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

  Widget _sheetSectionLabel(String label, Color textColor) {
    return Text(
      label,
      style: AppTextStyles.regularText.copyWith(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _filterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    Color primaryColor,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : textColor.withValues(alpha: 0.3),
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
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PalTuro',
              style: AppTextStyles.headingText.copyWith(color: textTheme),
            ),
            Row(
              children: [
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
          ],
        ),
      ),
      body: Padding(
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
            : _buildEmptyState(textTheme),
      ),
    );
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
            Text.rich(
              TextSpan(
                style: AppTextStyles.regularText.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                ),
                children: [
                  const TextSpan(text: 'No more people to show.\n'),
                  const TextSpan(text: 'Consider changing your '),
                  TextSpan(
                    text: 'Settings',
                    recognizer: _settingsTap,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
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
}