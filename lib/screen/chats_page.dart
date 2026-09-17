import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
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
              'Chats',
              style: AppTextStyles.headingText.copyWith(
                color: textTheme,
              ),
            )
              
          ),
        ),
      ),
      body: Center(
        child: Text('Chats'),
      ),
    );
  }
}
