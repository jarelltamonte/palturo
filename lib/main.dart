import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:palturo/authentication/email_confirmation_expired.dart';
import 'package:palturo/authentication/forgot_password_expired.dart';
import 'package:palturo/authentication/auth_gate.dart';
import 'package:palturo/services/activity_service.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/authentication/scratch.dart';
import 'package:palturo/root_gate.dart';
import 'package:palturo/authentication/forgot_password_3.dart';
import 'package:palturo/widgets/responsive_shell.dart';

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

  await Supabase.initialize(
    url: kSupabaseUrl,
    publishableKey: kSupabasePublishableKey,
  );

  await PreferencesService.instance.init();
  if (PreferencesService.instance.soundEnabled) {
    playSplashSound();
  }
  ChatStateService.instance.init();
  ActivityService.instance.init();
  final bool? isOnboardingDone = await PreferencesService.instance.getBool(
    'onboarding_done',
  );

  final bool? darkMode = await PreferencesService.instance.getBool('dark_mode');

  runApp(
    MyApp(
      isOnboardingDone: isOnboardingDone ?? false,
      initialDarkMode: darkMode ?? false,
    ),
  );
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
  const MyApp({
    super.key,
    required this.isOnboardingDone,
    this.initialDarkMode = false,
  });

  final bool isOnboardingDone;
  final bool initialDarkMode;

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
    PreferencesService.instance.setBool('dark_mode', isDark);
  }

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _linkSubscription;
  final _appLinks = AppLinks();

  Uri? _latestDeepLink;
  DateTime? _latestDeepLinkAt;
  Uri? _lastHandledLink;
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
    _themeMode = widget.initialDarkMode ? ThemeMode.dark : ThemeMode.light;

    // Keep the native splash only until Flutter paints its first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    _initAuthAndLinks();
  }

  /// Subscribe to auth first, then read the launch link. If signedIn fires
  /// before the link is known, the late-link handler consumes it.
  Future<void> _initAuthAndLinks() async {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _latestDeepLink = uri;
      _latestDeepLinkAt = DateTime.now();
      _handleLateLink(uri);
    });

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        final session = data.session;
        final user = session?.user;

        if (event == AuthChangeEvent.initialSession) {
          return;
        }
        if (event == AuthChangeEvent.signedOut) {
          _latestDeepLink = null;
          _latestDeepLinkAt = null;
          _lastHandledLink = null;
          return;
        }

        if (event == AuthChangeEvent.passwordRecovery) {
          _latestDeepLink = null;
          _latestDeepLinkAt = null;
          _openAuthScreen((_) => const ForgotPasswordType());
          return;
        }

        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.userUpdated) {
          if (_latestDeepLinkAt != null &&
              DateTime.now().difference(_latestDeepLinkAt!) >
                  const Duration(minutes: 2)) {
            _latestDeepLink = null;
            _latestDeepLinkAt = null;
          }

          if (_isAuthLink(_latestDeepLink, '/callback') &&
              user != null &&
              user.emailConfirmedAt != null) {
            final handled = _latestDeepLink;
            _latestDeepLink = null;
            _latestDeepLinkAt = null;
            _lastHandledLink = handled;

            _openAuthScreen(
              (_) => ScratchWidget(email: user.email, isConfirmedInitial: true),
            );
          }
        }
      },
      onError: (error) {
        if (error is AuthException) {
          final isResetCallback = _isAuthLink(
            _latestDeepLink,
            '/reset-callback',
          );
          final isSignupCallback = _isAuthLink(_latestDeepLink, '/callback');

          if (isResetCallback) {
            _latestDeepLink = null;
            _latestDeepLinkAt = null;
            _openAuthScreen((_) => const ForgotPasswordExpired());
            return;
          }

          if (isSignupCallback) {
            _latestDeepLink = null;
            _latestDeepLinkAt = null;
            _openAuthScreen((_) => const EmailConfirmationExpired());
          }
        }
      },
    );

    _appLinks
        .getInitialLink()
        .then((uri) {
          if (!mounted || uri == null) return;
          _latestDeepLink = uri;
          _latestDeepLinkAt = DateTime.now();
          _handleLateLink(uri);
        })
        .catchError((_) {});
  }

  bool _isAuthLink(Uri? uri, String path) {
    if (uri == null ||
        uri.scheme != 'palturo' ||
        uri.host != 'auth' ||
        uri.path != path) {
      return false;
    }
    final q = uri.queryParameters;
    final fragment = uri.fragment;
    return q.containsKey('code') ||
        q.containsKey('token_hash') ||
        q.containsKey('access_token') ||
        q.containsKey('error') ||
        fragment.contains('access_token=') ||
        fragment.contains('error=');
  }

  /// A link can arrive after signedIn (cold start race); route it once.
  void _handleLateLink(Uri uri) {
    final isCallback = _isAuthLink(uri, '/callback');
    final isReset = _isAuthLink(uri, '/reset-callback');
    if (!isCallback && !isReset) return;
    if (_lastHandledLink == uri) return;

    if (uri.queryParameters.containsKey('error')) {
      _lastHandledLink = uri;
      _latestDeepLink = null;
      _latestDeepLinkAt = null;
      _openAuthScreen(
        (_) =>
            isReset
                ? const ForgotPasswordExpired()
                : const EmailConfirmationExpired(),
      );
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (isCallback && session?.user.emailConfirmedAt != null) {
      _lastHandledLink = uri;
      _latestDeepLink = null;
      _latestDeepLinkAt = null;
      _openAuthScreen(
        (_) =>
            ScratchWidget(email: session!.user.email, isConfirmedInitial: true),
      );
    } else if (isReset && session != null) {
      _lastHandledLink = uri;
      _latestDeepLink = null;
      _latestDeepLinkAt = null;
      _openAuthScreen((_) => const ForgotPasswordType());
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
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
      builder:
          (context, child) =>
              ResponsiveShell(child: child ?? const SizedBox.shrink()),
      home: AppRootDecider(isOnboardingDone: widget.isOnboardingDone),
    );
  }
}
