import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/utils/friendly_error.dart';

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
