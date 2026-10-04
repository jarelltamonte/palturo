import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:palturo/landing_page.dart';
import 'package:palturo/onboarding_intro.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(
    widgetsBinding: widgetsBinding,
  );

  PreferencesService.instance.init();

  final isOnboardingDone =
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
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(
        const Duration(seconds: 3),
        FlutterNativeSplash.remove,
      );
    });
  }

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