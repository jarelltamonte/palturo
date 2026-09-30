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
    'Some caption... blah blah blad',
    'Some caption... blah blah blad',
    'Some caption... blah blah blad',
    'Some caption... blah blah blad',
  ];

  // TODO: replace with your real asset paths (and declare them in pubspec.yaml)
  // An empty string falls back to the plain grey card.
  final List<String> _categoryImage = [
    'assets/images/brand.png',
    'assets/images/brand.png',
    'assets/images/brand.png',
    'assets/images/brand.png',
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
            Icon(CupertinoIcons.search, color: textTheme, size: 24),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
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
                  imagePath: _categoryImage[index],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.description,
    required this.imagePath,
  });

  final String label;
  final String description;
  final String imagePath;

  // Soft shadow behind text as a second layer of legibility.
  static const _textShadows = [
    Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 1)),
    Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(24),
        // Optional soft drop shadow for the card itself
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background image
          if (hasImage)
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),

          // 2. Dark gradient scrim: keeps text readable on bright images
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.35, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(
                    alpha: hasImage ? 0.75 : 0.45,
                  ),
                ],
              ),
            ),
          ),

          // 3. Text pinned to the bottom
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headingText.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    shadows: _textShadows,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.9),
                    fontSize: 14,
                    shadows: _textShadows,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}