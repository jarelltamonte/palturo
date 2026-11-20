import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/utils/friendly_error.dart';
import 'package:palturo/utils/session_retry.dart';

void main() {
  test('friendly error separates network and validation failures', () {
    expect(
      friendlyError(Exception('SocketException: failed host lookup')),
      'Please check your connection and try again.',
    );
    expect(
      friendlyError(Exception('Invalid email address')),
      'Invalid email address',
    );
    expect(
      friendlyError(Exception('unexpected server state')),
      'Something went wrong. Please try again.',
    );
    expect(
      friendlyError(
        Exception('Too many deck requests. Please try again later.'),
      ),
      'Too many deck requests. Please try again later.',
    );
    expect(
      friendlyError(Exception('Passwords do not match')),
      'Passwords do not match',
    );
    expect(
      friendlyError(Exception('At least 8 characters (currently 5)')),
      'At least 8 characters (currently 5)',
    );
    expect(
      friendlyError(
        Exception('New password cannot be the same as the old password.'),
      ),
      'New password cannot be the same as the old password.',
    );
    expect(
      friendlyError(
        Exception(
          'Account deletion is temporarily unavailable. Please try again.',
        ),
      ),
      'Account deletion is temporarily unavailable. Please try again.',
    );
    expect(friendlyError(Exception('Add a number')), 'Add a number');

    // A revoked session arrives as a minified FunctionException; it must become
    // an actionable sign-in message, never driver text and never a retry loop.
    for (final session in [
      'minified:a0H(status: 401, details: {error: Unauthorized}, reasonPhrase: )',
      'AuthException(session_not_found: Session from session_id claim in JWT does not exist)',
      'JWT expired',
      'not authenticated',
    ]) {
      expect(
        friendlyError(Exception(session)),
        'Your session has expired. Please sign in again.',
        reason: session,
      );
    }

    expect(
      friendlyError(Exception('Failed to fetch')),
      'Please check your connection and try again.',
    );

    expect(
      friendlyError(const SessionExpiredException()),
      'Your session has expired. Please sign in again.',
    );

    expect(
      friendlyError(
        Exception(
          'For security purposes, you can only request this after 43 seconds.',
        ),
      ),
      'For security purposes, you can only request this after 43 seconds.',
    );

    expect(
      friendlyError(
        Exception(
          'AuthApiException(message: For security purposes, you can only '
          'request this after 43 seconds., statusCode: 429, '
          'code: over_email_send_rate_limit)',
        ),
      ),
      'Too many attempts. Please try again in 43 seconds.',
    );

    expect(
      friendlyError(
        Exception(
          'AuthApiException(message: Too many requests, statusCode: 429, '
          'code: over_request_rate_limit)',
        ),
      ),
      'Too many requests. Please wait a moment and try again.',
    );

    for (final technical in [
      'value too long for type character varying(120)',
      'password authentication failed for user "postgres"',
      'permission denied for table profiles',
      'invalid input syntax for type uuid: "abc"',
      'PostgrestException(message: boom, code: 42P01)',
    ]) {
      expect(
        friendlyError(Exception(technical)),
        'Something went wrong. Please try again.',
        reason: technical,
      );
    }
  });
}
