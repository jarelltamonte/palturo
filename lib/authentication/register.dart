import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/top_labeled_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
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
                'Back to Log In',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 16),
              ),
            ),
          ),
        ),
      ),

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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Expanded(child: TopLabeledField(label: 'First name')),
                          SizedBox(width: 16),
                          Expanded(child: TopLabeledField(label: 'Last name')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const TopLabeledField(label: 'Email'),
                      const SizedBox(height: 16),
                      TopLabeledField(
                        label: 'Password',
                        obscureText: _isPasswordObscured,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Theme.of(context).colorScheme.secondary.withAlpha(
                              (0.8 * 255).round(),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordObscured = !_isPasswordObscured;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      TopLabeledField(
                        label: 'Confirm password',
                        obscureText: _isConfirmPasswordObscured,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Theme.of(context).colorScheme.secondary.withAlpha(
                              (0.8 * 255).round(),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordObscured =
                                  !_isConfirmPasswordObscured;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            color: AppColors.white.withAlpha(
                              (0.7 * 255).round(),
                            ),
                            fontSize: 12,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(
                              text: 'By signing up, you agree to our\n',
                            ),
                            TextSpan(
                              text: 'Terms of Service, ',
                              style: AppTextStyles.boldText.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: 'Data Policy, ',
                              style: AppTextStyles.boldText.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const TextSpan(text: 'and '),
                            TextSpan(
                              text: '\nCookies Policy.',
                              style: AppTextStyles.boldText.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    textStyle: AppTextStyles.boldText,
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Sign Up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
