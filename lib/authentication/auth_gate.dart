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

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _evaluateUserStatus(_session);

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      if (data.session == null) {
        await PreferencesService.instance.setBool('skipped_onboarding', false);
        if (mounted) {
          setState(() {
            _hasSkipped = false;
          });
        }
      }
      _evaluateUserStatus(data.session);
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _evaluateUserStatus(Session? session) async {
    _session = session;

    if (session == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isProfileCompleted = false;
          _hasSkipped = false;
        });
      }
      return;
    }

    try {
      final metaCompleted =
          session.user.userMetadata?['is_profile_completed'] == true;
      if (metaCompleted) {
        if (mounted) {
          setState(() {
            _isProfileCompleted = true;
            _isLoading = false;
            _hasSkipped = false;
          });
        }
        return;
      }

      final savedSkip =
          await PreferencesService.instance.getBool('skipped_onboarding') ??
          false;

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

      if (mounted) {
        setState(() {
          _isProfileCompleted = completedOnboarding;
          _hasSkipped = savedSkip;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isProfileCompleted = false;
          _isLoading = false;
        });
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
