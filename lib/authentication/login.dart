import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/top_labeled_field.dart';
import 'package:palturo/authentication/register.dart';
import 'package:palturo/authentication/forgot_password_1.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isLoggingIn = false;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoggingIn = true);

    try {
      await _authService.login(email, password);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingIn = false);
      await _showLoginFailedDialog(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _showLoginFailedDialog(String message) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    return showAdaptiveDialog(
      context: context,
      builder: (dialogContext) {
        final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

        final title = Center(
          child: Text(
            'Login Failed',
            style: AppTextStyles.regularText.copyWith(
              color: textTheme,
              fontSize: 18,
            ),
          ),
        );

        final body = Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 14,
          ),
        );

        if (isIOS) {
          return CupertinoAlertDialog(
            title: title,
            content: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Material(color: Colors.transparent, child: body),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'OK',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          );
        }

        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: title,
          content: SizedBox(width: double.maxFinite, child: body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'OK',
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // Web: do not relayout the whole page when the browser keyboard/insets
      // fire on field focus — scroll instead (fixes the resize jump).
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.of(context).viewInsets.bottom,
                  ),
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

                      TopLabeledField(
                        label: 'Email',
                        controller: _emailController,
                      ),
                      const SizedBox(height: 10),

                      TopLabeledField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: _isObscured,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: textTheme.withAlpha((0.8 * 255).round()),
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscured = !_isObscured;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _login();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: AppTextStyles.boldText,
                            foregroundColor: AppColors.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child:
                              _isLoggingIn
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                  : const Text('Log In'),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
              const SizedBox(height: 10),
              Center(child: Image.asset('assets/images/brand.png', width: 145)),
            ],
          ),
        ),
      ),
    );
  }
}