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
  });
}
