import 'dart:async';
import 'package:flutter/material.dart';
import 'package:palturo/authentication/auth_gate.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const IntroScreen();
  }
}

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      // Never replace a route that was pushed above the splash (deep links,
      // recovery screens). Only advance when this route is still on top.
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Image.asset(
          isDarkMode
              ? 'assets/images/vlogo_white.png'
              : 'assets/images/vlogo_black.png',
          width: 320,
        ),
      ),
    );
  }
}
