import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:palturo/authentication/email_confirmation_expired.dart';
import 'package:palturo/authentication/forgot_password_expired.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/authentication/scratch.dart';
import 'package:palturo/root_gate.dart';
import 'package:palturo/authentication/forgot_password_3.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> playSplashSound() async {
  final player = AudioPlayer();
  try {
    player.onPlayerComplete.listen((_) => player.dispose());
    await player.play(AssetSource('sounds/splash.wav'));
  } catch (_) {
    await player.dispose();
  }
}

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  playSplashSound();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '',
  );

  PreferencesService.instance.init();
  final bool? isOnboardingDone = await PreferencesService.instance.getBool(
    'onboarding_done',
  );

  runApp(MyApp(isOnboardingDone: isOnboardingDone ?? false));
}

mixin MyAppThemeController on State<MyApp> {
  void setThemeMode(bool isDark);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.isOnboardingDone});

  final bool isOnboardingDone;

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

  late final StreamSubscription<AuthState> _authSubscription;
  StreamSubscription<Uri>? _linkSubscription;
  final _appLinks = AppLinks();

  Uri? _latestDeepLink;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), FlutterNativeSplash.remove);
    });

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _latestDeepLink = uri;
    });

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _latestDeepLink = uri;
    });

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        final session = data.session;
        final user = session?.user;

        if (event == AuthChangeEvent.initialSession ||
            event == AuthChangeEvent.signedOut) {
          return;
        }

        if (event == AuthChangeEvent.passwordRecovery) {
          _latestDeepLink = null;
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const ForgotPasswordType()),
            (route) => false,
          );
          return;
        }

        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.userUpdated) {
          final isSignupCallback =
              _latestDeepLink != null &&
              _latestDeepLink!.scheme == 'palturo' &&
              _latestDeepLink!.host == 'auth' &&
              _latestDeepLink!.path == '/callback';

          if (isSignupCallback &&
              user != null &&
              user.emailConfirmedAt != null) {
            final isPasswordRecovery =
                session?.user.appMetadata['recovery'] == true;
            if (isPasswordRecovery) return;

            _latestDeepLink = null;

            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder:
                    (context) => ScratchWidget(
                      email: user.email,
                      isConfirmedInitial: true,
                    ),
              ),
              (route) => false,
            );
          }
        }
      },
      onError: (error) {
        if (error is AuthException) {
          final isResetCallback =
              _latestDeepLink != null &&
              _latestDeepLink!.scheme == 'palturo' &&
              _latestDeepLink!.host == 'auth' &&
              _latestDeepLink!.path == '/reset-callback';

          final isSignupCallback =
              _latestDeepLink != null &&
              _latestDeepLink!.scheme == 'palturo' &&
              _latestDeepLink!.host == 'auth' &&
              _latestDeepLink!.path == '/callback';

          if (isResetCallback) {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const ForgotPasswordExpired(),
              ),
              (route) => false,
            );
            return;
          }

          if (isSignupCallback) {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const EmailConfirmationExpired(),
              ),
              (route) => false,
            );
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PalTuro',
      debugShowCheckedModeBanner: false,
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: _themeMode,
      home: AppRootDecider(isOnboardingDone: widget.isOnboardingDone),
    );
  }
}
