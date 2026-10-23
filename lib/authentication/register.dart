import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/top_labeled_field.dart';
import 'package:palturo/authentication/legal_dialogs.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';

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

  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  final AuthService _authService = AuthService();

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  bool _firstNameTouched = false;
  bool _lastNameTouched = false;
  bool _emailHasLostFocus = false;
  bool _passwordTouched = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _firstNameFocusNode.addListener(() {
      if (!_firstNameFocusNode.hasFocus && _firstNameController.text.isNotEmpty) {
        setState(() => _firstNameTouched = true);
      }
    });

    _lastNameFocusNode.addListener(() {
      if (!_lastNameFocusNode.hasFocus && _lastNameController.text.isNotEmpty) {
        setState(() => _lastNameTouched = true);
      }
    });

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && _emailController.text.isNotEmpty) {
        setState(() => _emailHasLostFocus = true);
      }
    });

    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus && !_passwordTouched) {
        setState(() => _passwordTouched = true);
      }
    });

    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? get _firstNameError {
    if (!_firstNameTouched && _firstNameController.text.isEmpty) return null;
    return Validators.validateName(_firstNameController.text, 'First name');
  }

  String? get _lastNameError {
    if (!_lastNameTouched && _lastNameController.text.isEmpty) return null;
    return Validators.validateName(_lastNameController.text, 'Last name');
  }

  String? get _emailError {
    if (!_emailHasLostFocus) return null;
    return Validators.validateEmail(_emailController.text);
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

  Future<void> _register() async {
    if (_isSubmitting) return;

    // Check if any field is empty - restore "All fields are required" pop up
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _firstNameTouched = true;
        _lastNameTouched = true;
        _emailHasLostFocus = true;
        _passwordTouched = true;
      });
      await _showSignUpFailedDialog('All fields are required');
      return;
    }

    // Validate email format
    final emailError = Validators.validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() {
        _emailHasLostFocus = true;
      });
      await _showSignUpFailedDialog(emailError);
      return;
    }

    // Validate name fields
    final firstNameError =
        Validators.validateName(_firstNameController.text, 'First name');
    if (firstNameError != null) {
      setState(() {
        _firstNameTouched = true;
      });
      await _showSignUpFailedDialog(firstNameError);
      return;
    }

    final lastNameError =
        Validators.validateName(_lastNameController.text, 'Last name');
    if (lastNameError != null) {
      setState(() {
        _lastNameTouched = true;
      });
      await _showSignUpFailedDialog(lastNameError);
      return;
    }

    // Validate password policy
    final passwordResult =
        Validators.checkPassword(_passwordController.text);
    if (!passwordResult.isValid) {
      setState(() {
        _passwordTouched = true;
      });
      final errorMsg = passwordResult.unmetRequirements.isNotEmpty
          ? passwordResult.unmetRequirements.first
          : 'Password does not meet security requirements.';
      await _showSignUpFailedDialog(errorMsg);
      return;
    }

    // Validate confirm password
    final confirmError = Validators.validateConfirmPassword(
      _passwordController.text,
      _confirmPasswordController.text,
    );
    if (confirmError != null) {
      await _showSignUpFailedDialog(confirmError);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _authService.register(
        _firstNameController.text,
        _lastNameController.text,
        _emailController.text,
        _passwordController.text,
        _confirmPasswordController.text,
      );

      // Clear sensitive password inputs
      _passwordController.clear();
      _confirmPasswordController.clear();

      // Reset loading state IMMEDIATELY before showing dialog so button spinner stops
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }

      if (!mounted) return;

      if (result.isSuccess) {
        await _showAccountCreatedDialog(
          message: result.message ??
              'If your account is ready, please log in to continue.',
        );

        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        await _showSignUpFailedDialog(
          result.message ?? 'Unable to create your account. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
      if (!mounted) return;
      await _showSignUpFailedDialog(
        'Unable to create your account. Please check your connection and try again.',
      );
    }
  }

  Future<void> _showAccountCreatedDialog({
    String message = 'Successfully created account. You may now log in.',
  }) async {
    final textTheme = Theme.of(context).colorScheme.secondary;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  'Next Step',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.boldText.copyWith(
                    color: textTheme,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Go to Log In',
                  style: AppTextStyles.boldText.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
    );
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
    final errorColor = Theme.of(context).colorScheme.error;
    final adaptiveHeight =
        Theme.of(context).platform == TargetPlatform.iOS ? 44.0 : 56.0;

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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TopLabeledField(
                                  label: 'First name',
                                  controller: _firstNameController,
                                  focusNode: _firstNameFocusNode,
                                  keyboardType: TextInputType.name,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.givenName,
                                  ],
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(
                                      Validators.maxNameLength,
                                    ),
                                  ],
                                ),
                                if (_firstNameError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      left: 4,
                                    ),
                                    child: Text(
                                      _firstNameError!,
                                      style:
                                          AppTextStyles.regularText.copyWith(
                                        color: errorColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TopLabeledField(
                                  label: 'Last name',
                                  controller: _lastNameController,
                                  focusNode: _lastNameFocusNode,
                                  keyboardType: TextInputType.name,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.familyName,
                                  ],
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(
                                      Validators.maxNameLength,
                                    ),
                                  ],
                                ),
                                if (_lastNameError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      left: 4,
                                    ),
                                    child: Text(
                                      _lastNameError!,
                                      style:
                                          AppTextStyles.regularText.copyWith(
                                        color: errorColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TopLabeledField(
                        label: 'Email',
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            Validators.maxEmailLength,
                          ),
                          Validators.emailDenyWhitespaceFormatter,
                        ],
                      ),
                      if (_emailError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            _emailError!,
                            style: AppTextStyles.regularText.copyWith(
                              color: errorColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
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
                            children: _passwordResult.unmetRequirements
                                .map((req) {
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
                                        style:
                                            AppTextStyles.regularText.copyWith(
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
                      const SizedBox(height: 10),
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
                  onPressed: _isSubmitting ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: AppTextStyles.boldText,
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isSubmitting
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
                      : const Text('Sign Up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
