import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:palturo/authentication/forgot_password_3.dart';

class ForgotPasswordCode extends StatelessWidget {
  const ForgotPasswordCode({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Padding(
          padding: const EdgeInsets.only(top: 32.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              icon: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).colorScheme.secondary,
                size: 16,
              ),
              label: Text(
                '',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Verify your identity',
                style: AppTextStyles.headingText.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 4-digit code sent to your email.',
                style: AppTextStyles.regularText.copyWith(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 32),

              OtpTextField(
                numberOfFields: 4,
                borderColor: Theme.of(context).colorScheme.secondary,
                enabledBorderColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                focusedBorderColor: AppColors.primary,
                borderWidth: 1.5,
                showFieldAsBox: true,
                fieldWidth: 55.0,
                borderRadius: BorderRadius.circular(12.0),
                textStyle: AppTextStyles.boldText.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 20,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.onPrimary,
                onCodeChanged: (String code) {
                },
                onSubmit: (String verificationCode) {
                  print("Code completed: $verificationCode");
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ForgotPasswordType(),
                      ),
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
              const SizedBox(height: 16),

              Center(
                  child: Text(
                    'Resend Code',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.boldText.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
