import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';

class HomePage extends StatefulWidget {
	const HomePage({super.key});

	@override
	State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
              'Home',
              style: AppTextStyles.headingText.copyWith(
                color: textTheme,
              ),
            )
              
          ),
        ),
      ),
			body: Center(
				child: Text('Home'),
			),
		);
	}
}
