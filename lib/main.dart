import 'package:flutter/material.dart';
import 'package:palturo/landing_page.dart';
import 'package:palturo/onboarding_intro.dart';
import 'package:palturo/services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PreferencesService.instance.init();
  bool? isOnboardingDone = await PreferencesService.instance.getBool(
    'onboarding_done',
  );
  runApp(MyApp(isOnboardingDone: isOnboardingDone ?? false));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.isOnboardingDone});

  final bool isOnboardingDone;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.brown,
          foregroundColor: Colors.white,
        ),
      ),
      home: isOnboardingDone ? const LandingPage() : const OnboardingIntro(),
    );
  }
}