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
import 'package:palturo/root_gate.dart';
import 'package:palturo/authentication/forgot_password_3.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Only HTTPS links on the owned auth origin may inject a Supabase session.
/// The custom `palturo://` scheme is used only for the tokenless app reopen.
bool _isTrustedAuthCallback(Uri uri) =>
    uri.scheme == 'https' &&
    (uri.host == 'palturo.app' || uri.host == 'www.palturo.app');


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

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    FlutterNativeSplash.remove();
    runApp(const MissingConfigurationApp());
    return;
  }

  playSplashSound();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      detectSessionInUriPredicate: _isTrustedAuthCallback,
    ),
  );

  PreferencesService.instance.init();
  final bool? isOnboardingDone = await PreferencesService.instance.getBool(
    'onboarding_done',
  );

  runApp(MyApp(isOnboardingDone: isOnboardingDone ?? false));
}

/// Shown when Supabase configuration was not supplied at build time.
/// Keeping this as a tiny standalone app avoids touching Supabase before it is
/// initialized and turns a silent splash into an actionable message.
class MissingConfigurationApp extends StatelessWidget {
  const MissingConfigurationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_suggest_outlined, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'PalTuro is not configured',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, then rebuild.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const SelectableText(
                    'flutter run --dart-define=SUPABASE_URL=... '
                    '--dart-define=SUPABASE_PUBLISHABLE_KEY=...',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Only the publishable key belongs in a client build.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      },
      onError: (error) {
        if (error is AuthException) {
          final link = _latestDeepLink;
          final hasError =
              link != null &&
              (link.queryParameters.containsKey('error') ||
                  link.fragment.contains('error='));
          final isResetCallback =
              hasError &&
              link.scheme == 'palturo' &&
              link.host == 'auth' &&
              link.path == '/reset-callback';

          final isSignupCallback =
              hasError &&
              link.scheme == 'palturo' &&
              link.host == 'auth' &&
              link.path == '/callback';

          if (isResetCallback) {
            _latestDeepLink = null;
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const ForgotPasswordExpired(),
              ),
              (route) => false,
            );
            return;
          }

          if (isSignupCallback) {
            _latestDeepLink = null;
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
