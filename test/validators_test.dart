import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email normalization and validation', () {
      expect(Validators.validateEmail('Person@Example.COM'), isNull);
      expect(
        Validators.normalizeEmail(' Person@Example.COM '),
        'person@example.com',
      );
      expect(Validators.validateEmail('not-an-email'), isNotNull);
      expect(Validators.validateEmail('a b@example.com'), isNotNull);
      expect(Validators.validateEmail(''), isNotNull);
    });

    test('password policy', () {
      expect(Validators.checkPassword('Abcdef1!').isValid, isTrue);
      expect(Validators.checkPassword('abcdef1!').hasUppercase, isFalse);
      expect(Validators.checkPassword('ABCDEF1!').hasLowercase, isFalse);
      expect(Validators.checkPassword('Abcdefg!').hasDigit, isFalse);
      expect(Validators.checkPassword('Abcdef12').hasSpecialChar, isFalse);
      expect(Validators.checkPassword('   ').isValid, isFalse);
    });

    test('names are sanitized and validated', () {
      expect(
        Validators.sanitizeName('  juan   de la cruz '),
        'Juan De La Cruz',
      );
      expect(Validators.validateName('van der berg', 'Last name'), isNull);
      expect(Validators.validateName('123', 'First name'), isNotNull);
      expect(Validators.validateName('   ', 'First name'), isNotNull);
    });

    test('confirmation only errors on a non-empty mismatch', () {
      expect(Validators.validateConfirmPassword('Abcdef1!', ''), isNull);
      expect(
        Validators.validateConfirmPassword('Abcdef1!', 'Abcdef1!'),
        isNull,
      );
      expect(
        Validators.validateConfirmPassword('Abcdef1!', 'Abcdef2!'),
        'Passwords do not match',
      );
    });
  });
}
