import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; 

class ScratchWidget extends StatefulWidget {
	const ScratchWidget({super.key});

	@override
	State<ScratchWidget> createState() => _ScratchWidgetState();
}

class _ScratchWidgetState extends State<ScratchWidget> {
	@override
	Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Lottie.asset(
            'assets/images/lottie_1.json',
            width: 350,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}
