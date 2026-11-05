import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/validators.dart';

enum LoginFailureKind {
  invalidCredentials,
  emailNotVerified,
  accountNotFound,
  rateLimited,
  network,
  invalidEmail,
  generic,
}

/// A user-facing login failure. The UI should show [message] and use
/// [canResendVerification] to offer a confirmation-email action.
class LoginFailure implements Exception {
  const LoginFailure(
    this.kind,
    this.message, {
    this.canResendVerification = false,
  });

  final LoginFailureKind kind;
  final String message;
  final bool canResendVerification;

  String get title {
    switch (kind) {
      case LoginFailureKind.invalidCredentials:
        return 'Email or password incorrect';
      case LoginFailureKind.emailNotVerified:
        return 'Email not verified';
      case LoginFailureKind.accountNotFound:
        return 'Account not found';
      case LoginFailureKind.rateLimited:
        return 'Too many attempts';
      case LoginFailureKind.network:
        return 'Connection problem';
      case LoginFailureKind.invalidEmail:
        return 'Check your email';
      case LoginFailureKind.generic:
        return 'Login failed';
    }
  }

  static LoginFailure fromAuthException(AuthException error) {
    if (error is AuthRetryableFetchException) {
      return network();
    }
    switch (error.code) {
      case 'invalid_credentials':
        return const LoginFailure(
          LoginFailureKind.invalidCredentials,
          'The email or password does not match a PalTuro account. Check your details, or reset your password if you have forgotten it.',
        );
      case 'email_not_confirmed':
        return const LoginFailure(
          LoginFailureKind.emailNotVerified,
          'Your email address has not been verified yet. Open the confirmation link we sent you, then try signing in again.',
          canResendVerification: true,
        );
      case 'user_not_found':
        return const LoginFailure(
          LoginFailureKind.accountNotFound,
          'No PalTuro account uses this email. Check the address or create a new account.',
        );
      case 'invalid_email':
      case 'validation_failed':
        return const LoginFailure(
          LoginFailureKind.invalidEmail,
          'That email address does not look valid. Check it and try again.',
        );
      case 'over_request_rate_limit':
      case 'too_many_requests':
        return const LoginFailure(
          LoginFailureKind.rateLimited,
          'Too many sign-in attempts. Wait a moment and try again.',
        );
      case 'email_provider_disabled':
      case 'signup_disabled':
        return const LoginFailure(
          LoginFailureKind.generic,
          'Email sign-in is not available right now. Please contact support.',
        );
      default:
        return const LoginFailure(
          LoginFailureKind.generic,
          'We could not sign you in. Check your details and try again.',
        );
    }
  }

  static LoginFailure network() => const LoginFailure(
    LoginFailureKind.network,
    'We could not reach PalTuro. Check your connection and try again.',
  );

  @override
  String toString() => message;
}

enum RegisterStatus { success, requiresConfirmation, neutral, failure }

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
      AuthRegisterResult._(status: RegisterStatus.success, response: response);

  factory AuthRegisterResult.requiresConfirmation(
    AuthResponse response, [
    String? message,
  ]) => AuthRegisterResult._(
    status: RegisterStatus.requiresConfirmation,
    message:
        message ??
        'Registration successful! Please check your email to confirm your account.',
    response: response,
  );

  factory AuthRegisterResult.neutral() => const AuthRegisterResult._(
    status: RegisterStatus.neutral,
    message:
        'If your account was created, log in to continue. If confirmation is enabled, check your email first.',
  );

  factory AuthRegisterResult.failure(String message) =>
      AuthRegisterResult._(status: RegisterStatus.failure, message: message);

  bool get isSuccess =>
      status == RegisterStatus.success ||
      status == RegisterStatus.requiresConfirmation ||
      status == RegisterStatus.neutral;
  bool get requiresConfirmation =>
      status == RegisterStatus.requiresConfirmation;
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isRegistering = false;
  static DateTime? _rateLimitCooldownUntil;

  /// Public origin used in Supabase auth email links.
  ///
  /// On web, a custom scheme such as `palturo://` cannot be opened by a
  /// browser, so the redirect must be an HTTPS (or localhost) URL. Set
  /// APP_PUBLIC_URL at build time for production, for example
  /// `--dart-define=APP_PUBLIC_URL=https://palturo.app`.
  ///
  /// On native, the app keeps its deep-link callback.
  String _authRedirect(String mobilePath) {
    if (!kIsWeb) return 'palturo://auth/$mobilePath';

    const configured = String.fromEnvironment('APP_PUBLIC_URL');
    if (configured.isNotEmpty) {
      return configured.endsWith('/') ? configured : '$configured/';
    }

    final base = Uri.base;
    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    return '${base.origin}$path';
  }

  // login
  Future<AuthResponse> login(String email, String password) async {
    final cleanEmail = Validators.normalizeEmail(email);
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const LoginFailure(
        LoginFailureKind.invalidCredentials,
        'Enter your email address and password to sign in.',
      );
    }

    try {
      final response = await _supabase.auth
          .signInWithPassword(email: cleanEmail, password: password)
          .timeout(const Duration(seconds: 30));

      final user = response.user;

      if (user == null) {
        throw const LoginFailure(
          LoginFailureKind.generic,
          'We could not sign you in. Check your details and try again.',
        );
      }

      if (user.emailConfirmedAt == null) {
        await _supabase.auth.signOut();
        throw const LoginFailure(
          LoginFailureKind.emailNotVerified,
          'Your email address has not been verified yet. Open the confirmation link we sent you, then try signing in again.',
          canResendVerification: true,
        );
      }

      return response;
    } on LoginFailure {
      rethrow;
    } on AuthException catch (e) {
      throw LoginFailure.fromAuthException(e);
    } on TimeoutException {
      throw LoginFailure.network();
    } on SocketException {
      throw LoginFailure.network();
    } catch (_) {
      throw const LoginFailure(
        LoginFailureKind.generic,
        'We could not sign you in. Check your details and try again.',
      );
    }
  }

  Future<void> resendVerificationEmail(String email) async {
    final cleanEmail = Validators.normalizeEmail(email);
    if (cleanEmail.isEmpty) {
      throw const LoginFailure(
        LoginFailureKind.invalidEmail,
        'Enter a valid email address before requesting another confirmation link.',
      );
    }
    try {
      await _supabase.auth
          .resend(
            email: cleanEmail,
            type: OtpType.signup,
            emailRedirectTo: _authRedirect('callback'),
          )
          .timeout(const Duration(seconds: 30));
    } on AuthException catch (e) {
      if (e.code == 'over_email_send_rate_limit') {
        throw const LoginFailure(
          LoginFailureKind.rateLimited,
          'A confirmation email was requested too recently. Wait a moment, then try again.',
        );
      }
      throw LoginFailure.fromAuthException(e);
    } on TimeoutException {
      throw LoginFailure.network();
    } on SocketException {
      throw LoginFailure.network();
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
    final firstNameError = Validators.validateName(
      cleanFirstName,
      'First name',
    );
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
      final reason =
          passwordResult.unmetRequirements.isNotEmpty
              ? passwordResult.unmetRequirements.first
              : 'Password does not meet security requirements.';
      return AuthRegisterResult.failure(reason);
    }

    final confirmError = Validators.validateConfirmPassword(password, confirm);
    if (confirmError != null) {
      return AuthRegisterResult.failure(confirmError);
    }

    _isRegistering = true;
    try {
      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'first_name': cleanFirstName, 'last_name': cleanLastName},
        emailRedirectTo: _authRedirect('callback'),
      );

      // Handle email confirmation edge case:
      // When confirmation is enabled and the email already exists,
      // Supabase returns a user with empty identities instead of an AuthException.
      if (response.user != null &&
          (response.user!.identities == null ||
              response.user!.identities!.isEmpty)) {
        return AuthRegisterResult.neutral();
      }

      // With confirmation enabled signUp has no session and returns neutral.
      // If autoconfirm is ever re-enabled, still avoid auto-login/enumeration.
      if (response.session != null) {
        try {
          await _supabase.auth.signOut();
        } catch (_) {}
      }
      return AuthRegisterResult.neutral();
    } on AuthException catch (e) {
      if (e.code == 'user_already_exists') {
        return AuthRegisterResult.neutral();
      }
      if (e.code == 'over_email_send_rate_limit') {
        // A new signup sends mail; an existing one does not. Never expose that
        // difference through a distinct failure.
        return AuthRegisterResult.neutral();
      }
      if (e.code == 'over_request_rate_limit') {
        _rateLimitCooldownUntil = DateTime.now().add(
          const Duration(seconds: 30),
        );
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
        return 'Could not create an account. If you already have one, sign in or reset your password.';
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
      final message =
          details is Map && details['error'] is String
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

  // Send Reset Link
  Future<void> sendPasswordResetLink(String email) async {
    final cleanEmail = Validators.normalizeEmail(email);

    if (cleanEmail.isEmpty) {
      throw Exception('Email is required');
    }

    try {
      await _supabase.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: _authRedirect('reset-callback'),
      );
    } on AuthException catch (e) {
      if (e.code == 'over_email_send_rate_limit') {
        // Do not reveal whether this address exists by distinguishing a
        // rate-limited existing address from a nonexistent one.
        return;
      }
      throw Exception('Could not send a reset link. Please try again.');
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

    final confirmError = Validators.validateConfirmPassword(
      password,
      confirmPassword,
    );
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
        throw Exception(
          'Too many requests. Please wait a moment and try again.',
        );
      }
      throw Exception('Unable to reset password. Please try again.');
    } on SocketException catch (_) {
      throw Exception(
        'Unable to connect to server. Please check your internet connection and try again.',
      );
    } on TimeoutException catch (_) {
      throw Exception(
        'Connection timed out. Please check your internet connection and try again.',
      );
    } catch (e) {
      if (e is AuthRetryableFetchException) {
        throw Exception(
          'Network connection issue. Please check your internet connection and try again.',
        );
      }
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
