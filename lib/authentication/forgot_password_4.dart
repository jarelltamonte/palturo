import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import 'login.dart';

class ForgotPasswordComplete extends StatefulWidget {
  const ForgotPasswordComplete({super.key});

  @override
  State<ForgotPasswordComplete> createState() => _ForgotPasswordCompleteState();
}

class _ForgotPasswordCompleteState extends State<ForgotPasswordComplete> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/lottie_finished.json',
                width: 350,
                repeat: false,
                animate: true,
              ),
              Text(
                'Password Reset Complete!',
                style: AppTextStyles.headingText.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Your password has been reset successfully.\nContinue to login.',
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    textStyle: AppTextStyles.boldText,
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
