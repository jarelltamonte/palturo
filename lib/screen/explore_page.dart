import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final List<String> _categoryLabels = [
    'Arts and Design',
    'Language and Cultural Knowledge',
    'Everyday Practical Skills',
    'Agriculture and Livelihood',
  ];

  final List<String> _categoryDescription = [
    'Weaving, embroidery, and handmade crafts',
    'Dialects, stories, and living heritage',
    'Cooking, repairs, and daily know-how',
    'Farming, fishing, and local trades',
  ];

  final List<IconData> _categoryIcons = [
    Icons.palette_outlined,
    Icons.translate,
    Icons.handyman_outlined,
    Icons.agriculture_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Explore',
              style: AppTextStyles.headingText.copyWith(color: textTheme),
            ),
            IconButton(
              icon: Icon(
                CupertinoIcons.question_circle,
                color: textTheme,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                showAdaptiveDialog(
                  context: context,
                  builder: (context) => const _ExploreInfoDialog(),
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 16.0;
            final itemHeight = (constraints.maxHeight - spacing) / 2;

            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                mainAxisExtent: itemHeight,
              ),
              itemCount: _categoryLabels.length,
              itemBuilder: (context, index) {
                return _CategoryCard(
                  label: _categoryLabels[index],
                  description: _categoryDescription[index],
                  icon: _categoryIcons[index],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ExploreInfoDialog extends StatefulWidget {
  const _ExploreInfoDialog();

  @override
  State<_ExploreInfoDialog> createState() => _ExploreInfoDialogState();
}

class _ExploreInfoDialogState extends State<_ExploreInfoDialog> {
  static const _titles = ['Explore', 'Heads up'];

  static const _messages = [
    'Browse categories to discover skills and knowledge shared by other users. Pick a category, then swipe through people who are teaching or learning in it.',
    'Most people you swipe on here won\'t match the skills you declared. That\'s intentional: Explore is for discovering something new, so keep an open mind.',
  ];

  int _page = 0;

  bool get _isLastPage => _page == _titles.length - 1;

  void _next() {
    if (_isLastPage) {
      Navigator.pop(context);
    } else {
      setState(() => _page++);
    }
  }

  void _back() {
    setState(() => _page--);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    final title = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        _titles[_page],
        key: ValueKey('title_$_page'),
        style: AppTextStyles.regularText.copyWith(
          color: textTheme,
          fontSize: 18,
        ),
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Step ${_page + 1} of ${_titles.length}',
          style: AppTextStyles.regularText.copyWith(
            color: textTheme.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (_page + 1) / _titles.length),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: textTheme.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _messages[_page],
              key: ValueKey('message_$_page'),
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );

    if (isIOS) {
      return CupertinoAlertDialog(
        title: title,
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(color: Colors.transparent, child: content),
        ),
        actions: [
          if (_page > 0)
            CupertinoDialogAction(
              onPressed: _back,
              child: Text(
                'Back',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
              ),
            ),
          CupertinoDialogAction(
            onPressed: _next,
            child: Text(
              _isLastPage ? 'Okay' : 'Next',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: title,
      content: SizedBox(width: double.maxFinite, child: content),
      actions: [
        if (_page > 0)
          TextButton(
            onPressed: _back,
            child: Text(
              'Back',
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
          ),
        TextButton(
          onPressed: _next,
          child: Text(
            _isLastPage ? 'Okay' : 'Next',
            style: AppTextStyles.regularText.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.background),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.headingText.copyWith(
              color: textColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
