import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/services/auth_service.dart';

void main() {
  test('invalid credentials gets a specific message', () {
    final failure = LoginFailure.fromAuthException(
      const AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      ),
    );

    expect(failure.kind, LoginFailureKind.invalidCredentials);
    expect(failure.title, 'Email or password incorrect');
    expect(failure.message, contains('password'));
    expect(failure.canResendVerification, isFalse);
  });

  test('unverified email offers resend', () {
    final failure = LoginFailure.fromAuthException(
      const AuthException('Email not confirmed', code: 'email_not_confirmed'),
    );

    expect(failure.kind, LoginFailureKind.emailNotVerified);
    expect(failure.title, 'Email not verified');
    expect(failure.message, contains('confirmation link'));
    expect(failure.canResendVerification, isTrue);
  });

  test('rate limits and missing accounts have distinct copy', () {
    final rate = LoginFailure.fromAuthException(
      const AuthException('Too many requests', code: 'too_many_requests'),
    );
    final missing = LoginFailure.fromAuthException(
      const AuthException('User not found', code: 'user_not_found'),
    );

    expect(rate.kind, LoginFailureKind.rateLimited);
    expect(rate.message, contains('Too many'));
    expect(missing.kind, LoginFailureKind.accountNotFound);
    expect(missing.title, 'Account not found');
  });

  test('transport failures get connection copy', () {
    final failure = LoginFailure.fromAuthException(
      AuthRetryableFetchException(),
    );

    expect(failure.kind, LoginFailureKind.network);
    expect(failure.title, 'Connection problem');
    expect(failure.canResendVerification, isFalse);
  });

  test('unknown auth failures stay actionable without leaking internals', () {
    final failure = LoginFailure.fromAuthException(
      const AuthException('unexpected internal detail'),
    );

    expect(failure.kind, LoginFailureKind.generic);
    expect(failure.message, isNot(contains('unexpected internal detail')));
  });
}
