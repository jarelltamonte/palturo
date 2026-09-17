import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
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
              'Requests',
              style: AppTextStyles.headingText.copyWith(
                color: textTheme,
              ),
            )
              
          ),
        ),
      ),
      body: Center(
        child: Text('Request Page'),
      ),
    );
  }
}
