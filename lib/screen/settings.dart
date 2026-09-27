import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/theme/app_text_styles.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.close, color: textTheme),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Settings',
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 16,
          ),
        ),
      ),
      body: const Center(child: Text('Settings')),
    );
  }
}
