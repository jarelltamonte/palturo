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

    test('name rules give a specific message per failure', () {
      final cases = <String, String>{
        '': 'First name is required.',
        'A': 'First name must be at least 2 letters.',
        'John3': 'Names cannot contain numbers.',
        'John 😀': 'Names cannot contain emoji or symbols.',
        'John@':
            'Names can only use letters, spaces, hyphens, and apostrophes.',
        'John Jacob Jingleheimer Schmidt':
            'Please use at most 3 words per name.',
        'Aaaa':
            'That doesn’t look like a real name. Please enter your actual name.',
        'qwerty':
            'That doesn’t look like a real name. Please enter your actual name.',
        'asdkjhasd':
            'That doesn’t look like a real name. Please enter your actual name.',
        'Test': 'Please enter your real name, not a placeholder.',
        'Fuck':
            'This name contains language that isn’t allowed. '
            'Please enter your real name.',
      };
      cases.forEach((input, message) {
        expect(
          Validators.validateName(input, 'First name'),
          message,
          reason: input,
        );
      });
    });

    test('valid names cover international, hyphen, apostrophe, suffix', () {
      for (final name in [
        'Li',
        'Ñúñez',
        'O’Brien',
        'Jean-Luc',
        'Mary Jane',
        'van der Berg',
        'Dela Cruz Jr.',
        'Juan',
        'D’Angelo',
      ]) {
        expect(
          Validators.validateName(name, 'Last name'),
          isNull,
          reason: name,
        );
      }
    });

    test('detailed name validation returns the sanitized value', () {
      final result = Validators.validateNameDetailed(
        '  juan   de la ',
        'First name',
      );
      expect(result.isValid, isTrue);
      expect(result.sanitized, 'Juan De La');

      final mixed = Validators.validateNameDetailed('McDonald', 'Last name');
      expect(mixed.sanitized, 'McDonald');
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
