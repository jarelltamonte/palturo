import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_text_styles.dart';
import 'forgot_password_3.dart';
import 'login.dart';

class ForgotPasswordWait extends StatefulWidget {
  final String email;
  final bool isConfirmedInitial;

  const ForgotPasswordWait({
    super.key,
    required this.email,
    this.isConfirmedInitial = false,
  });

  @override
  State<ForgotPasswordWait> createState() => _ForgotPasswordWaitState();
}

class _ForgotPasswordWaitState extends State<ForgotPasswordWait> {
  late final StreamSubscription<AuthState> _authSubscription;
  late bool _linkConfirmed;

  @override
  void initState() {
    super.initState();
    _linkConfirmed = widget.isConfirmedInitial;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (!mounted) return;

      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() => _linkConfirmed = true);
        _navigateToResetPassword();
      }
    });
  }

  void _navigateToResetPassword() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordType()),
    );
  }

  void _returnToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
            icon: Icon(Icons.arrow_back_ios, color: textTheme, size: 16),
            label: Text('', style: TextStyle(color: textTheme, fontSize: 16)),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/lottie_finished.json',
                width: 260,
                repeat: !_linkConfirmed,
                animate: true,
              ),
              const SizedBox(height: 24),
              Text(
                _linkConfirmed ? 'Reset Link Verified!' : 'Check your email',
                style: AppTextStyles.headingText.copyWith(color: textTheme),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _linkConfirmed
                    ? 'Redirecting to reset your password...'
                    : 'We sent a password reset link to\n${widget.email}.\n\nClick the link in your email to continue on this device.',
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
          child: TextButton(
            onPressed: _returnToLogin,
            style: TextButton.styleFrom(
              foregroundColor: textTheme.withValues(alpha: 0.7),
              textStyle: AppTextStyles.regularText,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cancel and Return to Login'),
          ),
        ),
      ),
    );
  }
}
