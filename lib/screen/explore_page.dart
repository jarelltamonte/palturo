import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Padding(
          padding: const EdgeInsets.only(top: 32.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text (
              'Explore',
              style: AppTextStyles.headingText.copyWith(
                color: textTheme,
              ),
            )
              
          ),
        ),
      ),
      body: const Center(
        child: Text('Explore'),
      ),
    );
  }
}
