import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:palturo/authentication/scratch.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/top_labeled_field.dart';
import 'package:palturo/authentication/legal_dialogs.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    try {
      final response = await _authService.register(
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _confirmPasswordController.text,
      );

      if (!mounted) return;

      final isAlreadyConfirmed =
          response.session != null || response.user?.emailConfirmedAt != null;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => ScratchWidget(
                email: _emailController.text.trim(),
                isConfirmedInitial: isAlreadyConfirmed,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await _showSignUpFailedDialog(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _showSignUpFailedDialog(String message) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    return showAdaptiveDialog(
      context: context,
      builder: (dialogContext) {
        final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

        final title = Center(
          child: Text(
            'Sign Up Failed',
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
            label: Text(
              'Back to Log In',
              style: TextStyle(color: textTheme, fontSize: 16),
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
                      const SizedBox(height: 44),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TopLabeledField(
                              label: 'First name',
                              controller: _firstNameController,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TopLabeledField(
                              label: 'Last name',
                              controller: _lastNameController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TopLabeledField(
                        label: 'Email',
                        controller: _emailController,
                      ),
                      const SizedBox(height: 10),
                      TopLabeledField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: _isPasswordObscured,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: textTheme.withAlpha((0.8 * 255).round()),
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordObscured = !_isPasswordObscured;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      TopLabeledField(
                        label: 'Confirm password',
                        controller: _confirmPasswordController,
                        obscureText: _isConfirmPasswordObscured,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: textTheme.withAlpha((0.8 * 255).round()),
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordObscured =
                                  !_isConfirmPasswordObscured;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 64),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              color: textTheme.withAlpha((0.7 * 255).round()),
                              fontSize: 12,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(
                                text: 'By signing up, you agree to our ',
                              ),
                              TextSpan(
                                text: 'Terms of Service',
                                style: AppTextStyles.boldText.copyWith(
                                  color: textTheme,
                                  fontSize: 12,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap = () {
                                        LegalDialogs.showTermsOfService(
                                          context,
                                        );
                                      },
                              ),
                              const TextSpan(text: ', '),
                              TextSpan(
                                text: 'Data Policy',
                                style: AppTextStyles.boldText.copyWith(
                                  color: textTheme,
                                  fontSize: 12,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap = () {
                                        LegalDialogs.showDataPolicy(context);
                                      },
                              ),
                              const TextSpan(text: ', and '),
                              TextSpan(
                                text: 'Cookies Policy',
                                style: AppTextStyles.boldText.copyWith(
                                  color: textTheme,
                                  fontSize: 12,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap = () {
                                        LegalDialogs.showCookiesPolicy(context);
                                      },
                              ),
                              const TextSpan(text: '.'),
                            ],
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
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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