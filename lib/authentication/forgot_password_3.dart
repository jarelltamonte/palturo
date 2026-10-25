import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/top_labeled_field.dart';
import 'package:palturo/authentication/forgot_password_4.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';

class ForgotPasswordType extends StatefulWidget {
  const ForgotPasswordType({super.key});

  @override
  State<ForgotPasswordType> createState() => _ForgotPasswordTypeState();
}

class _ForgotPasswordTypeState extends State<ForgotPasswordType> {
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _isLoading = false;

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_handleChange);
    _confirmPasswordController.addListener(_handleChange);
    _passwordFocusNode.addListener(_handleChange);
    _confirmPasswordFocusNode.addListener(_handleChange);
  }

  void _handleChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  PasswordValidationResult get _passwordResult =>
      Validators.checkPassword(_passwordController.text);

  String? get _confirmPasswordError {
    if (_confirmPasswordController.text.isEmpty) return null;
    return Validators.validateConfirmPassword(
      _passwordController.text,
      _confirmPasswordController.text,
    );
  }

  Future<void> _showErrorDialog(String message) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.elevatedSurface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Password Reset Failed',
            style: AppTextStyles.boldText.copyWith(
              color: textTheme,
              fontSize: 18,
            ),
          ),
          content: Text(
            message,
            style: AppTextStyles.regularText.copyWith(
              color: textTheme.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: AppTextStyles.boldText.copyWith(
                  color: AppColors.accentText(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetPassword() async {
    if (_isLoading) return;

    if (_passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      await _showErrorDialog('All fields are required');
      return;
    }

    final passwordResult = _passwordResult;
    if (!passwordResult.isValid) {
      final errorMsg =
          passwordResult.unmetRequirements.isNotEmpty
              ? passwordResult.unmetRequirements.first
              : 'Password does not meet security requirements.';
      await _showErrorDialog(errorMsg);
      return;
    }

    final confirmError = _confirmPasswordError;
    if (confirmError != null) {
      await _showErrorDialog(confirmError);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.updatePassword(
        _passwordController.text,
        _confirmPasswordController.text,
      );

      _passwordController.clear();
      _confirmPasswordController.clear();

      // Stop loading indicator immediately upon receiving response
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ForgotPasswordComplete()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (!mounted) return;

      await _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final errorColor = Theme.of(context).colorScheme.error;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    final showPasswordChecklist =
        (_passwordFocusNode.hasFocus || _passwordController.text.isNotEmpty) &&
        !_passwordResult.isValid;

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
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios, color: textTheme, size: 16),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Reset your password',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headingText.copyWith(color: textTheme),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your new password below.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 32),
                TopLabeledField(
                  label: 'Password',
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _isPasswordObscured,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      Validators.maxPasswordLength,
                    ),
                  ],
                  suffixIcon: IconButton(
                    tooltip:
                        _isPasswordObscured ? 'Show password' : 'Hide password',
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
                if (showPasswordChecklist)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          _passwordResult.unmetRequirements.map((req) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 5,
                                    color: errorColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      req,
                                      style: AppTextStyles.regularText.copyWith(
                                        color: errorColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                TopLabeledField(
                  label: 'Confirm password',
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocusNode,
                  obscureText: _isConfirmPasswordObscured,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      Validators.maxPasswordLength,
                    ),
                  ],
                  suffixIcon: IconButton(
                    tooltip:
                        _isConfirmPasswordObscured
                            ? 'Show confirmation password'
                            : 'Hide confirmation password',
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
                if (_confirmPasswordError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      _confirmPasswordError!,
                      style: AppTextStyles.regularText.copyWith(
                        color: errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? () {} : _resetPassword,
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
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.textSecondary,
                                ),
                              ),
                            )
                            : const Text('Reset Password'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
