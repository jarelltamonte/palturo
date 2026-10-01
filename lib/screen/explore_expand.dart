import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/theme/app_text_styles.dart';

class ExploreExpand extends StatefulWidget {
	const ExploreExpand({super.key});

	@override
	State<ExploreExpand> createState() => _ExploreExpandState();
}

class _ExploreExpandState extends State<ExploreExpand> {
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
            Icon(CupertinoIcons.question_circle, color: textTheme, size: 24),
          ],
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text(
                  'Explore',
                  style: AppTextStyles.headingText.copyWith(color: textTheme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
