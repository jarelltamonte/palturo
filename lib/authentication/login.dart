import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/top_labeled_field.dart';
import 'package:palturo/authentication/register.dart';
import 'package:palturo/authentication/forgot_password_1.dart';
import 'package:palturo/onboarding/onboarding_1.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Hero(
                          tag: 'logo',
                          child: Image.asset(
                            isDarkMode
                                ? 'assets/images/logo_white.png'
                                : 'assets/images/logo_black.png',
                            width: 285,
                          ),
                        ),
                      ),
                      const SizedBox(height: 56),

                      const TopLabeledField(label: 'Email'),
                      const SizedBox(height: 16),

                      TopLabeledField(
                        label: 'Password',
                        obscureText: _isObscured,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Theme.of(context).colorScheme.secondary
                                .withAlpha((0.8 * 255).round()),
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscured = !_isObscured;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const OnboardingIntro(),
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
                          child: const Text('Log In'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ForgotPassword(),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.boldText.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    textStyle: AppTextStyles.boldText,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Create new account'),
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Image.asset('assets/images/brand.png', width: 145)),
            ],
          ),
        ),
      ),
    );
  }
}
