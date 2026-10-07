import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'login.dart';
import 'register.dart';

class EmailConfirmationExpired extends StatelessWidget {
  const EmailConfirmationExpired({super.key});

  void _navigateToRegister(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
      (route) => false,
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 88,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Link Expired or Already Confirmed',
                  style: AppTextStyles.headingText.copyWith(color: textTheme),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTextStyles.regularText.copyWith(
                      color: textTheme.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'This confirmation link is no longer valid or has already been completed.\n\nIf you have already verified your account, continue to log in. Otherwise, you can ',
                      ),
                      TextSpan(
                        text: 'sign up again',
                        style: AppTextStyles.boldText.copyWith(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer:
                            TapGestureRecognizer()
                              ..onTap = () => _navigateToRegister(context),
                      ),
                      const TextSpan(text: ' to request a new link.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => _navigateToLogin(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: AppTextStyles.boldText,
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Back to Login'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _navigateToRegister(context),
                style: TextButton.styleFrom(
                  foregroundColor: textTheme.withValues(alpha: 0.8),
                  textStyle: AppTextStyles.regularText,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Sign Up Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
