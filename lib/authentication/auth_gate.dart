import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/authentication/login.dart';
import 'package:palturo/onboarding/onboarding_flow.dart';
import 'package:palturo/screen/navigation_bar.dart';
import 'package:palturo/services/preferences_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  Session? _session;
  bool _isLoading = true;
  bool _isProfileCompleted = false;
  bool _hasSkipped = false;
  bool _loadError = false;
  int _evaluationId = 0;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _evaluateUserStatus(_session);

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      if (data.session == null) {
        await _evaluateUserStatus(null);
        try {
          await PreferencesService.instance.setBool('skipped_onboarding', false);
        } catch (_) {}
        if (mounted) {
          setState(() {
            _hasSkipped = false;
          });
        }
      } else {
        await _evaluateUserStatus(data.session);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _evaluateUserStatus(Session? session) async {
    final evaluation = ++_evaluationId;
    final userId = session?.user.id;
    final sameUser = userId != null && userId == _lastUserId;
    _session = session;

    if (session == null) {
      _lastUserId = null;
      if (mounted && evaluation == _evaluationId) {
        setState(() {
          _isLoading = false;
          _isProfileCompleted = false;
          _hasSkipped = false;
          _loadError = false;
        });
      }
      return;
    }

    // Token refreshes for the same user must not unmount the app shell.
    final showLoading = !sameUser || _loadError;
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
        _loadError = false;
      });
    }

    try {
      final metaCompleted =
          session.user.userMetadata?['is_profile_completed'] == true;
      if (metaCompleted) {
        if (mounted && evaluation == _evaluationId) {
          setState(() {
            _isProfileCompleted = true;
            _isLoading = false;
            _hasSkipped = false;
            _lastUserId = userId;
            _loadError = false;
          });
        }
        return;
      }

      var savedSkip = false;
      try {
        savedSkip =
            await PreferencesService.instance.getBool('skipped_onboarding') ??
            false;
      } catch (_) {
        // Preferences are optional; fall through to the profile query.
      }

      final data = await Supabase.instance.client
          .from('profiles')
          .select('has_completed_onboarding, is_profile_completed')
          .eq('id', session.user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      final completedOnboarding =
          data != null &&
          ((data['has_completed_onboarding'] == true) ||
              (data['is_profile_completed'] == true));

      if (mounted && evaluation == _evaluationId) {
        setState(() {
          _isProfileCompleted = completedOnboarding;
          _hasSkipped = savedSkip;
          _isLoading = false;
          _lastUserId = userId;
          _loadError = false;
        });
      }
    } catch (_) {
      if (mounted && evaluation == _evaluationId) {
        // A background refresh failure must not replace a working app.
        if (showLoading || _lastUserId == null) {
          setState(() {
            _isProfileCompleted = false;
            _isLoading = false;
            _loadError = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Couldn’t load your profile. Please try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _loadError = false;
                    });
                    _evaluateUserStatus(_session);
                  },
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await Supabase.instance.client.auth.signOut();
                    } catch (_) {}
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_session == null) {
      return const LoginPage();
    }

    if (_isProfileCompleted || _hasSkipped) {
      return const NavigationBarWidget();
    }

    return OnboardingFlow(
      onFinished: () {
        _evaluateUserStatus(_session);
      },
      onSkip: () async {
        await PreferencesService.instance.setBool('skipped_onboarding', true);
        if (mounted) {
          setState(() {
            _hasSkipped = true;
          });
        }
      },
    );
  }
}
