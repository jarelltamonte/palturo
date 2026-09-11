import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';

class OnboardingComplete extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingComplete({super.key, required this.onDone});

  @override
  State<OnboardingComplete> createState() => _OnboardingCompleteState();
}

class _OnboardingCompleteState extends State<OnboardingComplete> {
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
                'You\'re all set!',
                style: AppTextStyles.headingText.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Your account setup is complete.\nLet’s get started.',
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
                  onPressed: widget.onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    textStyle: AppTextStyles.boldText,
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
