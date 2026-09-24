import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/theme/app_text_styles.dart';

class ChatRoom extends StatefulWidget {
	const ChatRoom({super.key});

	@override
	State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> {
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
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Align(
            alignment: Alignment.centerLeft,
            child: Text (
              'Explore',
              style: AppTextStyles.boldText.copyWith(
                color: textTheme,
              ),
            )
              
        ),
      ),
      body: const Center(
        child: Text('Explore'),
      ),
    );
  }
}
