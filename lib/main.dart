import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:palturo/authentication/email_confirmation_expired.dart';
import 'package:palturo/authentication/forgot_password_expired.dart';
import 'package:palturo/authentication/auth_gate.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/authentication/scratch.dart';
import 'package:palturo/root_gate.dart';
import 'package:palturo/authentication/forgot_password_3.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Compile-time configuration. Pass these with
//   flutter run --dart-define-from-file=.env
// or with individual --dart-define flags. They are never bundled as assets.
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

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

  if (kSupabaseUrl.isEmpty || kSupabasePublishableKey.isEmpty) {
    FlutterNativeSplash.remove();
    runApp(const MissingConfigurationApp());
    return;
  }

  playSplashSound();

  await Supabase.initialize(
    url: kSupabaseUrl,
    publishableKey: kSupabasePublishableKey,
  );

  PreferencesService.instance.init();
  ChatStateService.instance.init();
  final bool? isOnboardingDone = await PreferencesService.instance.getBool(
    'onboarding_done',
  );

  runApp(MyApp(isOnboardingDone: isOnboardingDone ?? false));
}

/// Shown when Supabase configuration was not supplied at build time.
/// Keeping this as a tiny standalone app avoids touching Supabase before it is
/// initialized and turns a silent black screen into an actionable message.
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
                    'flutter run --dart-define-from-file=.env',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'See .env.example for the expected values.',
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
  WidgetBuilder? _pendingAuthScreen;
  int _authScreenRetry = 0;

  /// Replaces the whole stack with a fresh AuthGate root, then pushes the
  /// deep-link screen above it. This guarantees that `popUntil(isFirst)`
  /// always reveals the auth gate - even during the splash/onboarding phase,
  /// where the first route is not AuthGate yet - and disposes the landing
  /// timer so it cannot replace the deep-link screen.
  void _openAuthScreen(WidgetBuilder builder) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (!mounted || _authScreenRetry >= 10) return;
      _authScreenRetry++;
      _pendingAuthScreen = builder;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pending = _pendingAuthScreen;
        _pendingAuthScreen = null;
        if (pending != null) _openAuthScreen(pending);
      });
      return;
    }
    _authScreenRetry = 0;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
    navigator.push(MaterialPageRoute(builder: builder));
  }

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
          _openAuthScreen((_) => const ForgotPasswordType());
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

            _openAuthScreen(
              (_) => ScratchWidget(email: user.email, isConfirmedInitial: true),
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
            _openAuthScreen((_) => const ForgotPasswordExpired());
            return;
          }

          if (isSignupCallback) {
            _openAuthScreen((_) => const EmailConfirmationExpired());
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
