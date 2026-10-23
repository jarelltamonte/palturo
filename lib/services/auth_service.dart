import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/validators.dart';

enum RegisterStatus {
  success,
  requiresConfirmation,
  failure,
}

class AuthRegisterResult {
  final RegisterStatus status;
  final String? message;
  final AuthResponse? response;

  const AuthRegisterResult._({
    required this.status,
    this.message,
    this.response,
  });

  factory AuthRegisterResult.success(AuthResponse response) =>
      AuthRegisterResult._(
        status: RegisterStatus.success,
        response: response,
      );

  factory AuthRegisterResult.requiresConfirmation(
    AuthResponse response, [
    String? message,
  ]) =>
      AuthRegisterResult._(
        status: RegisterStatus.requiresConfirmation,
        message: message ??
            'Registration successful! Please check your email to confirm your account.',
        response: response,
      );

  factory AuthRegisterResult.failure(String message) => AuthRegisterResult._(
        status: RegisterStatus.failure,
        message: message,
      );

  bool get isSuccess =>
      status == RegisterStatus.success ||
      status == RegisterStatus.requiresConfirmation;
  bool get requiresConfirmation =>
      status == RegisterStatus.requiresConfirmation;
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isRegistering = false;
  static DateTime? _rateLimitCooldownUntil;

  // login
  Future<AuthResponse> login(String email, String password) async {
    final cleanEmail = Validators.normalizeEmail(email);
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw Exception('Email and Password are required');
    }

    try {
      final response = await _supabase.auth
          .signInWithPassword(email: cleanEmail, password: password)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception(
              'Sign in timed out. Please check your connection.',
            ),
          );

      final user = response.user;

      if (user == null) {
        throw Exception('Unable to login. Please try again.');
      }

      if (user.emailConfirmedAt == null) {
        await _supabase.auth.signOut();
        throw Exception('Please confirm your email before logging in.');
      }

      return response;
    } on AuthException catch (e) {
      if (e.code == 'invalid_credentials') {
        throw Exception('Invalid Email or Password');
      }
      throw Exception('Unable to login. Please try again.');
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // register
  Future<AuthRegisterResult> register(
    String firstName,
    String lastName,
    String email,
    String password,
    String confirm,
  ) async {
    // In-flight guard
    if (_isRegistering) {
      return AuthRegisterResult.failure(
        'A registration request is already in progress.',
      );
    }

    // Cooldown check
    if (_rateLimitCooldownUntil != null &&
        DateTime.now().isBefore(_rateLimitCooldownUntil!)) {
      final remaining =
          _rateLimitCooldownUntil!.difference(DateTime.now()).inSeconds + 1;
      return AuthRegisterResult.failure(
        'Too many attempts. Please wait $remaining seconds before trying again.',
      );
    }

    // Input sanitization (password is NEVER trimmed or altered)
    final cleanFirstName = Validators.sanitizeName(firstName);
    final cleanLastName = Validators.sanitizeName(lastName);
    final cleanEmail = Validators.normalizeEmail(email);

    // Validation
    final firstNameError = Validators.validateName(cleanFirstName, 'First name');
    if (firstNameError != null) {
      return AuthRegisterResult.failure(firstNameError);
    }

    final lastNameError = Validators.validateName(cleanLastName, 'Last name');
    if (lastNameError != null) {
      return AuthRegisterResult.failure(lastNameError);
    }

    final emailError = Validators.validateEmail(cleanEmail);
    if (emailError != null) {
      return AuthRegisterResult.failure(emailError);
    }

    final passwordResult = Validators.checkPassword(password);
    if (!passwordResult.isValid) {
      final reason = passwordResult.unmetRequirements.isNotEmpty
          ? passwordResult.unmetRequirements.first
          : 'Password does not meet security requirements.';
      return AuthRegisterResult.failure(reason);
    }

    final confirmError = Validators.validateConfirmPassword(password, confirm);
    if (confirmError != null) {
      return AuthRegisterResult.failure(confirmError);
    }

    // Check email in profiles if available without throwing unhandled exceptions
    try {
      final alreadyExists = await checkEmailExists(cleanEmail);
      if (alreadyExists) {
        return AuthRegisterResult.failure(
          'An account with this email already exists.',
        );
      }
    } catch (_) {
      // Allow auth.signUp to be the ultimate source of truth
    }

    _isRegistering = true;
    try {
      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'first_name': cleanFirstName, 'last_name': cleanLastName},
        emailRedirectTo: 'palturo://auth/callback',
      );

      // Handle email confirmation edge case:
      // When confirmation is enabled and the email already exists,
      // Supabase returns a user with empty identities instead of an AuthException.
      if (response.user != null &&
          (response.user!.identities == null ||
              response.user!.identities!.isEmpty)) {
        return AuthRegisterResult.failure(
          'An account with this email already exists.',
        );
      }

      if (response.session == null) {
        return AuthRegisterResult.requiresConfirmation(
          response,
          'Registration successful! Please check your email to confirm your account.',
        );
      }

      return AuthRegisterResult.success(response);
    } on AuthException catch (e) {
      if (e.code == 'over_request_rate_limit' ||
          e.code == 'over_email_send_rate_limit') {
        _rateLimitCooldownUntil =
            DateTime.now().add(const Duration(seconds: 30));
      }
      final message = _mapAuthException(e);
      return AuthRegisterResult.failure(message);
    } on SocketException catch (_) {
      return AuthRegisterResult.failure(
        'Unable to connect to server. Please check your internet connection and try again.',
      );
    } on TimeoutException catch (_) {
      return AuthRegisterResult.failure(
        'Connection timed out. Please check your internet connection and try again.',
      );
    } catch (e) {
      if (e is AuthRetryableFetchException) {
        return AuthRegisterResult.failure(
          'Network connection issue. Please check your internet connection and try again.',
        );
      }
      return AuthRegisterResult.failure(
        'Unable to create your account. Please try again.',
      );
    } finally {
      _isRegistering = false;
    }
  }

  static String _mapAuthException(AuthException e) {
    switch (e.code) {
      case 'user_already_exists':
        return 'An account with this email already exists.';
      case 'weak_password':
        return 'Password does not meet security requirements.';
      case 'invalid_credentials':
        return 'Invalid email or password.';
      case 'signup_disabled':
      case 'signups_not_allowed':
        return 'Registration is currently disabled. Please contact support.';
      case 'over_request_rate_limit':
        return 'Too many requests. Please wait a moment and try again.';
      case 'over_email_send_rate_limit':
        return 'Too many confirmation emails were requested. Please try again later.';
      case 'validation_failed':
        return 'Invalid registration details. Please check your information.';
      default:
        return 'Unable to create your account. Please try again.';
    }
  }

  // logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  /// Permanently deletes the signed-in user's profile, media and auth account
  /// via the `delete-account` Edge Function, then clears the local session.
  Future<void> deleteAccount() async {
    try {
      await _supabase.functions.invoke('delete-account', body: const {});
    } on FunctionException catch (e) {
      if (e.status == 0) {
        throw Exception(
          'Unable to delete your account. Please check your connection and try again.',
        );
      }
      if (e.status == 429) {
        throw Exception(
          'Too many attempts. Please wait a few minutes and try again.',
        );
      }
      if (e.status == 503) {
        throw Exception(
          'Account deletion is temporarily unavailable. Please try again.',
        );
      }
      final details = e.details;
      final message = details is Map && details['error'] is String
          ? details['error'] as String
          : details is String && details.isNotEmpty
          ? details
          : 'Unable to delete your account. Please try again.';
      throw Exception(message);
    } catch (_) {
      throw Exception(
        'Unable to delete your account. Please check your connection and try again.',
      );
    }

    // The account is gone at this point; clear local credentials so the UI
    // returns to login even if the network call cannot reach the server.
    try {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // signOut clears local credentials before the request, so ignore.
    }
  }

  // Current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Verify Email
  Future<bool> checkEmailExists(String email) async {
    try {
      final cleanEmail = Validators.normalizeEmail(email);
      final exists = await _supabase.rpc(
        'email_exists',
        params: {'p_email': cleanEmail},
      );
      return exists == true;
    } catch (_) {
      return false;
    }
  }

  // Send Reset Link
  Future<void> sendPasswordResetLink(String email) async {
    final cleanEmail = Validators.normalizeEmail(email);

    if (cleanEmail.isEmpty) {
      throw Exception('Email is required');
    }

    final exists = await checkEmailExists(cleanEmail);
    if (!exists) {
      throw Exception('No account found with this email');
    }

    try {
      await _supabase.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: 'palturo://auth/reset-callback',
      );
    } on AuthException catch (e) {
      if (e.code == 'over_email_send_rate_limit') {
        throw Exception(
          'Too many password reset requests. Please try again later.',
        );
      }
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Failed to send password reset link. Please try again.');
    }
  }

  // Update Password
  Future<void> updatePassword(String password, String confirmPassword) async {
    if (password.isEmpty || confirmPassword.isEmpty) {
      throw Exception('All fields are required');
    }

    final passwordResult = Validators.checkPassword(password);
    if (!passwordResult.isValid) {
      throw Exception(
        passwordResult.unmetRequirements.isNotEmpty
            ? passwordResult.unmetRequirements.first
            : 'Password does not meet security requirements.',
      );
    }

    final confirmError = Validators.validateConfirmPassword(password, confirmPassword);
    if (confirmError != null) {
      throw Exception(confirmError);
    }

    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } on AuthException catch (e) {
      if (e.code == 'same_password') {
        throw Exception('New password cannot be the same as the old password.');
      }
      if (e.code == 'weak_password') {
        throw Exception('Password does not meet security requirements.');
      }
      if (e.code == 'over_request_rate_limit') {
        throw Exception('Too many requests. Please wait a moment and try again.');
      }
      throw Exception('Unable to reset password. Please try again.');
    } on SocketException catch (_) {
      throw Exception('Unable to connect to server. Please check your internet connection and try again.');
    } on TimeoutException catch (_) {
      throw Exception('Connection timed out. Please check your internet connection and try again.');
    } catch (e) {
      if (e is AuthRetryableFetchException) {
        throw Exception('Network connection issue. Please check your internet connection and try again.');
      }
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
