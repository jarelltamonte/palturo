import 'package:flutter/material.dart';
import 'package:palturo/landing_page.dart';
import 'package:palturo/onboarding_intro.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PreferencesService.instance.init();

  bool? isOnboardingDone =
      await PreferencesService.instance.getBool('onboarding_done');

  runApp(
    MyApp(
      isOnboardingDone: isOnboardingDone ?? false,
    ),
  );
}
mixin MyAppThemeController on State<MyApp> {
  void setThemeMode(bool isDark);
}

class MyApp extends StatefulWidget {
  final bool isOnboardingDone;

  const MyApp({
    super.key,
    required this.isOnboardingDone,
  });

  static MyAppThemeController of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>()!;
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with MyAppThemeController {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void setThemeMode(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Palturo',
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: _themeMode,
      home: widget.isOnboardingDone
          ? const LandingPage()
          : const OnboardingIntro(),
    );
  }
}
