import 'package:flutter/material.dart';
import 'package:palturo/landing_page.dart';
import 'package:palturo/onboarding_intro.dart';

class AppRootDecider extends StatefulWidget {
  final bool isOnboardingDone;

  const AppRootDecider({super.key, required this.isOnboardingDone});

  @override
  State<AppRootDecider> createState() => _AppRootDeciderState();
}

class _AppRootDeciderState extends State<AppRootDecider> {
  bool _isCheckingInitialLink = true;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isCheckingInitialLink = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingInitialLink) {
      return Scaffold(backgroundColor: Theme.of(context).colorScheme.surface);
    }

    return widget.isOnboardingDone
        ? const LandingPage()
        : const OnboardingIntro();
  }
}
