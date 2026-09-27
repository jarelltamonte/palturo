import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/screen/card/person_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Person> _people = const [
    Person(
      id: '1',
      name: 'RJ Santos',
      schedule: 'Mon/Wed/Sat',
      language: 'English',
      learningStyle: 'Discussion',
      skillName: 'Parol Making',
      role: PersonRole.learner,
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
      photoUrls: [null, null],
    ),
  ];

  int _currentIndex = 0;

  void _next() {
    setState(() {
      _currentIndex++;
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
                Icon(CupertinoIcons.arrow_uturn_left,
                    color: textTheme, size: 24),
                const SizedBox(width: 16),
                Icon(Icons.tune, color: textTheme, size: 24),
              ],
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        child: hasMore
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
                  onAdd: _next,
                  onSkip: _next,
                  onBlock: () => _block(_people[_currentIndex].id),
                  onReport: () => _report(_people[_currentIndex].id),
                ),
              )
            : Center(
                child: Text(
                  'No more people to show right now.',
                  style: AppTextStyles.regularText.copyWith(color: textTheme),
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
}