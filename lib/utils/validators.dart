import 'package:flutter/services.dart';
import 'package:palturo/utils/name_policy.dart';

/// Password validation breakdown describing unmet requirements.
class PasswordValidationResult {
  final bool isValid;
  final int currentLength;
  final bool hasMinLength;
  final bool hasMaxLength;
  final bool hasLowercase;
  final bool hasUppercase;
  final bool hasDigit;
  final bool hasSpecialChar;
  final bool isNotWhitespaceOnly;
  final List<String> unmetRequirements;

  const PasswordValidationResult({
    required this.isValid,
    required this.currentLength,
    required this.hasMinLength,
    required this.hasMaxLength,
    required this.hasLowercase,
    required this.hasUppercase,
    required this.hasDigit,
    required this.hasSpecialChar,
    required this.isNotWhitespaceOnly,
    required this.unmetRequirements,
  });
}

class Validators {
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 72; // bcrypt limit
  static const int maxEmailLength = 254; // RFC 5321 limit
  static const int maxNameLength = 50;

  // Regex rules
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );
  static final RegExp _lowercaseRegExp = RegExp(r'[a-z]');
  static final RegExp _uppercaseRegExp = RegExp(r'[A-Z]');
  static final RegExp _digitRegExp = RegExp(r'[0-9]');
  // Special characters: symbols and punctuation (ASCII + standard unicode symbols)
  static final RegExp _specialCharRegExp = RegExp(
    r'''[!@#$%^&*()_+\-=\[\]{}|;':",.<>\/?`~\\§±]''',
  );
  static final RegExp _controlAndZeroWidthRegExp = RegExp(
    r'[\u0000-\u001F\u007F\u200B-\u200D\uFEFF]',
  );

  /// Deny whitespace inside email addresses.
  static final TextInputFormatter emailDenyWhitespaceFormatter =
      FilteringTextInputFormatter.deny(RegExp(r'\s'));

  /// Capitalize the first letter of each word in a string.
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          final firstChar = word.substring(0, 1).toUpperCase();
          final rest = word.length > 1 ? word.substring(1) : '';
          return '$firstChar$rest';
        })
        .join(' ');
  }

  /// Normalize email by trimming outer whitespace and lowercasing.
  static String normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  /// Sanitizes name inputs by stripping invisible/format characters,
  /// normalizing typography and spaces, and applying display casing.
  static String sanitizeName(String name) => NamePolicy.sanitize(name);

  /// Validates email address according to RFC standards and security rules.
  static String? validateEmail(String? rawEmail) {
    if (rawEmail == null || rawEmail.trim().isEmpty) {
      return 'Email is required';
    }

    // Check for internal whitespace or control characters
    if (rawEmail.contains(RegExp(r'\s')) ||
        rawEmail.contains(_controlAndZeroWidthRegExp)) {
      return 'Email cannot contain spaces or invalid characters';
    }

    final normalized = normalizeEmail(rawEmail);

    if (normalized.length > maxEmailLength) {
      return 'Email cannot exceed $maxEmailLength characters';
    }

    if (!_emailRegExp.hasMatch(normalized)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Evaluates password against Supabase policy and bcrypt bounds.
  /// Password is never trimmed or altered.
  static PasswordValidationResult checkPassword(String password) {
    final length = password.length;
    final hasMin = length >= minPasswordLength;
    final hasMax = length <= maxPasswordLength;
    final hasLower = _lowercaseRegExp.hasMatch(password);
    final hasUpper = _uppercaseRegExp.hasMatch(password);
    final hasDig = _digitRegExp.hasMatch(password);
    final hasSpecial = _specialCharRegExp.hasMatch(password);
    final notWhitespaceOnly = password.trim().isNotEmpty;

    final unmet = <String>[];

    if (length == 0 || !notWhitespaceOnly) {
      unmet.add('Password cannot be empty or only spaces');
    } else {
      if (!hasMin) {
        unmet.add('At least $minPasswordLength characters (currently $length)');
      }
      if (!hasMax) {
        unmet.add('Password cannot exceed $maxPasswordLength characters');
      }
      if (!hasLower) {
        unmet.add('Add a lowercase letter');
      }
      if (!hasUpper) {
        unmet.add('Add an uppercase letter');
      }
      if (!hasDig) {
        unmet.add('Add a number');
      }
      if (!hasSpecial) {
        unmet.add('Add a special character');
      }
    }

    final isValid =
        hasMin &&
        hasMax &&
        hasLower &&
        hasUpper &&
        hasDig &&
        hasSpecial &&
        notWhitespaceOnly;

    return PasswordValidationResult(
      isValid: isValid,
      currentLength: length,
      hasMinLength: hasMin,
      hasMaxLength: hasMax,
      hasLowercase: hasLower,
      hasUppercase: hasUpper,
      hasDigit: hasDig,
      hasSpecialChar: hasSpecial,
      isNotWhitespaceOnly: notWhitespaceOnly,
      unmetRequirements: unmet,
    );
  }

  /// Validates password match for confirmation field.
  static String? validateConfirmPassword(
    String password,
    String confirmPassword,
  ) {
    if (confirmPassword.isEmpty) {
      return null;
    }
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validates first or last name field with deterministic rules.
  static String? validateName(String? rawName, String fieldLabel) {
    return NamePolicy.validate(rawName, fieldLabel).error;
  }

  /// Same rules, but also returns the sanitized value for saving.
  static NameValidation validateNameDetailed(
    String? rawName,
    String fieldLabel,
  ) {
    return NamePolicy.validate(rawName, fieldLabel);
  }
}
