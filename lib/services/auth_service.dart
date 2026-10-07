import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  //login
  Future<AuthResponse> login(String email, String password) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw Exception('Email and Password are required');
    }

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
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

  //register
  Future<AuthResponse> register(
    String firstName,
    String lastName,
    String email,
    String password,
    String confirm,
  ) async {
    final cleanFirstName = firstName.trim();
    final cleanLastName = lastName.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final cleanConfirm = confirm.trim();

    if (cleanFirstName.isEmpty ||
        cleanLastName.isEmpty ||
        cleanEmail.isEmpty ||
        cleanPassword.isEmpty ||
        cleanConfirm.isEmpty) {
      throw Exception('All fields are required');
    }

    if (cleanPassword != cleanConfirm) {
      throw Exception('Passwords do not match');
    }

    final alreadyExists = await checkEmailExists(cleanEmail);
    if (alreadyExists) {
      throw Exception('An account with this email already exists.');
    }

    try {
      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: cleanPassword,
        data: {'first_name': cleanFirstName, 'last_name': cleanLastName},
        emailRedirectTo: 'palturo://auth/callback',
      );

      if (response.user != null &&
          (response.user!.identities == null ||
              response.user!.identities!.isEmpty)) {
        throw Exception('An account with this email already exists.');
      }

      return response;
    } on AuthException catch (e) {
      if (e.code == 'over_email_send_rate_limit') {
        throw Exception(
          'Too many confirmation emails were requested. Please try again later.',
        );
      }
      if (e.code == 'user_already_exists') {
        throw Exception('An account with this email already exists.');
      }
      throw Exception('Unable to create your account. Please try again.');
    } catch (e) {
      throw Exception('Something went wrong. Please try again.');
    }
  }

  //logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  //Current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  //Verify Email
  Future<bool> checkEmailExists(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();

      final data =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('email', cleanEmail)
              .maybeSingle();
      return data != null;
    } catch (e) {
      throw Exception('Unable to check email. Please try again.');
    }
  }

  //Send Reset Link
  Future<void> sendPasswordResetLink(String email) async {
    final cleanEmail = email.trim().toLowerCase();

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

  //Update Password
  Future<void> updatePassword(String password, String confirmPassword) async {
    final cleanPassword = password.trim();
    final cleanConfirm = confirmPassword.trim();
    if (cleanPassword.isEmpty || cleanConfirm.isEmpty) {
      throw Exception('All fields are required');
    }

    if (cleanPassword != cleanConfirm) {
      throw Exception('Passwords do not match');
    }

    try {
      await _supabase.auth.updateUser(UserAttributes(password: cleanPassword));
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } on AuthException catch (e) {
      if (e.code == 'same_password') {
        throw Exception('New password cannot be the same as the old password.');
      }
      throw Exception('Unable to reset password. Please try again.');
    } catch (e) {
      throw Exception('Something went wrong. Please try again.');
    }
  }
}
