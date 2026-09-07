import 'package:flutter/material.dart';
import 'authentication/login.dart';
import 'theme/app_colors.dart';

class LandingPage extends StatelessWidget {
	const LandingPage({super.key});

	@override
	Widget build(BuildContext context) {
		return const MaterialApp(
			debugShowCheckedModeBanner: false,
			home: IntroScreen(),
		);
	}
}

class IntroScreen extends StatefulWidget {
	const IntroScreen({super.key});

	@override
	State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
	@override
	void initState() {
		super.initState();

		Future.delayed(const Duration(seconds: 3), () {
			if (mounted) {
				Navigator.pushReplacement(
					context,
					MaterialPageRoute(builder: (context) => const LoginPage()),
				);
			}
		});
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			body: Center(
				child: Image.asset(
					'assets/images/vlogo.png',
					width: 320,
				),
			),
		);
	}
}
