import 'package:flutter/material.dart';
import 'package:palturo/landing_page.dart';
import 'package:palturo/onboarding_intro.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';


void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
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
    FlutterNativeSplash.remove();
    
    return MaterialApp(
      title: 'Palturo',
      debugShowCheckedModeBanner: false,
      theme: lightMode,
      darkTheme: darkMode,
      home: isOnboardingDone ? const LandingPage() : const OnboardingIntro(),
    );
  }
}