/// Deterministic display-name rules.
///
/// No inference here: every rejection comes from a fixed character set,
/// bounded heuristics, or a curated blocklist. Keep this list in step with
/// `public.name_blocklist` in the display-name migration.
library;

import 'package:flutter/services.dart';

enum NameErrorCode {
  requiredField,
  tooShort,
  tooLong,
  tooManyWords,
  numbers,
  emojiOrSymbols,
  invalidPunctuation,
  repeatedOrMash,
  placeholder,
  profanity,
  sameNames,
  mixedAlphabet,
}

class NameValidation {
  const NameValidation({required this.sanitized, this.code, this.error});

  final String sanitized;
  final NameErrorCode? code;
  final String? error;

  bool get isValid => error == null;
}

class NamePolicy {
  static const int maxLength = 50;
  static const int minLetters = 2;
  static const int maxWords = 3;

  static final RegExp _letter = RegExp(r'[\p{L}\p{M}]', unicode: true);
  static final RegExp _lettersOnly = RegExp(r'^[\p{L}\p{M}]+$', unicode: true);
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _symbol = RegExp(
    r'[\p{So}\p{Sk}\p{Sm}\p{Sc}]',
    unicode: true,
  );
  static final RegExp _format = RegExp(
    r'[\u0000-\u001F\u007F\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
  );
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _repeated = RegExp(r'(.)\1{3,}', caseSensitive: false);
  static final RegExp _keyboardMash = RegExp(
    r'(qwe|wer|ert|rty|tyu|yui|uio|iop|asd|sdf|dfg|fgh|ghj|hjk|jkl|zxc|xcv|cvb|vbn|bnm)',
    caseSensitive: false,
  );
  static final RegExp _consonantRun = RegExp(r'[bcdfghjklmnpqrstvwxz]{6,}');

  // Script buckets used only to reject a single token that mixes alphabets
  // (a common spoofing trick). Separate name tokens may use different scripts.
  static final List<RegExp> _scriptBuckets = [
    RegExp(r'[A-Za-z\u00C0-\u024F]'),
    RegExp(r'[\u0370-\u03FF]'),
    RegExp(r'[\u0400-\u04FF]'),
    RegExp(r'[\u0590-\u05FF]'),
    RegExp(r'[\u0600-\u06FF]'),
    RegExp(r'[\u0900-\u097F]'),
    RegExp(r'[\u0E00-\u0E7F]'),
    RegExp(r'[\u3040-\u30FF]'),
    RegExp(r'[\u4E00-\u9FFF]'),
    RegExp(r'[\uAC00-\uD7AF]'),
  ];

  static const Set<String> placeholders = {
    'test',
    'testing',
    'tester',
    'user',
    'username',
    'admin',
    'administrator',
    'asdf',
    'asdfgh',
    'qwerty',
    'qwertyuiop',
    'name',
    'firstname',
    'lastname',
    'anonymous',
    'null',
    'none',
    'xxx',
    'abc',
    'abcdef',
    'sample',
    'demo',
    'guest',
    'temp',
    'default',
    'unknown',
    'palturo',
    'support',
    'official',
  };

  static const Set<String> profanity = {
    // English
    'fuck',
    'fucked',
    'fucker',
    'fuckers',
    'fucking',
    'shit',
    'shitty',
    'bullshit',
    'bitch',
    'bitches',
    'cunt',
    'asshole',
    'assholes',
    'bastard',
    'whore',
    'slut',
    'faggot',
    'fag',
    'nigger',
    'nigga',
    'retard',
    'retarded',
    'rape',
    'rapist',
    'porn',
    'pussy',
    'wanker',
    'twat',
    'douche',
    // Filipino / Tagalog
    'puta',
    'putangina',
    'putanginamo',
    'tangina',
    'tanginamo',
    'gago',
    'gaga',
    'bobo',
    'ulol',
    'punyeta',
    'kupal',
    'tarantado',
    'pakshet',
    'kingina',
    'iyot',
    'kantot',
    'hinayupak',
    'hayop',
  };

  static const Set<String> profanityPhrases = {
    'putangina',
    'putanginamo',
    'tanginamo',
    'anakngputa',
    'sonofabitch',
    'pieceofshit',
    'fuckyou',
  };

  /// Common Latin accents folded so blocklists still see the word.
  static const Map<String, String> _accentFold = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ñ': 'n',
    'ç': 'c',
    'ý': 'y',
    'ÿ': 'y',
  };

  /// Normalizes typography and strips invisible/format characters.
  static String sanitize(String raw) {
    final replaced = raw
        .replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B\u2032]'), "'")
        .replaceAll(RegExp(r'[\u2010-\u2015\u2212]'), '-')
        .replaceAll(_format, '');
    return _capWords(replaced.replaceAll(_whitespace, ' ').trim());
  }

  static NameValidation validate(String? raw, String label) {
    final text = sanitize(raw ?? '');
    if (text.isEmpty) {
      return _fail(label, NameErrorCode.requiredField, '$label is required.');
    }
    if (text.length > maxLength) {
      return _fail(
        text,
        NameErrorCode.tooLong,
        '$label cannot exceed $maxLength characters.',
      );
    }
    if (_digit.hasMatch(text)) {
      return _fail(
        text,
        NameErrorCode.numbers,
        'Names cannot contain numbers.',
      );
    }
    if (_symbol.hasMatch(text)) {
      return _fail(
        text,
        NameErrorCode.emojiOrSymbols,
        'Names cannot contain emoji or symbols.',
      );
    }

    // Only letters, marks, spaces, hyphens, apostrophes, and a single trailing
    // period are allowed.
    final stripped = text.replaceAll(
      RegExp(r"[\p{L}\p{M} '\-.]", unicode: true),
      '',
    );
    if (stripped.isNotEmpty) {
      return _fail(
        text,
        NameErrorCode.invalidPunctuation,
        'Names can only use letters, spaces, hyphens, and apostrophes.',
      );
    }

    final tokens = text.split(' ').where((token) => token.isNotEmpty).toList();
    if (tokens.length > maxWords) {
      return _fail(
        text,
        NameErrorCode.tooManyWords,
        'Please use at most $maxWords words per name.',
      );
    }

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final dotCount = '.'.allMatches(token).length;
      if (dotCount > 0 &&
          (dotCount > 1 || i != tokens.length - 1 || !token.endsWith('.'))) {
        return _fail(
          text,
          NameErrorCode.invalidPunctuation,
          'Names can only use letters, spaces, hyphens, and apostrophes.',
        );
      }
      final letters = token.replaceAll('.', '');
      final plain = letters.replaceAll(RegExp(r"['\-]", unicode: true), '');
      if (!_lettersOnly.hasMatch(plain) ||
          _letter.allMatches(plain).length < minLetters) {
        return _fail(
          text,
          NameErrorCode.tooShort,
          '$label must be at least $minLetters letters.',
        );
      }
      if (_scriptBuckets.where((re) => re.hasMatch(plain)).length > 1) {
        return _fail(
          text,
          NameErrorCode.mixedAlphabet,
          'Please use one alphabet per name.',
        );
      }
      if (_looksLikeMash(plain)) {
        return _fail(
          text,
          NameErrorCode.repeatedOrMash,
          'That doesn’t look like a real name. Please enter your actual name.',
        );
      }
      final folded = _fold(plain);
      if (placeholders.contains(folded)) {
        return _fail(
          text,
          NameErrorCode.placeholder,
          'Please enter your real name, not a placeholder.',
        );
      }
      if (_isProfane(folded)) {
        return _fail(
          text,
          NameErrorCode.profanity,
          'This name contains language that isn’t allowed. '
          'Please enter your real name.',
        );
      }
    }

    final compact = _compact(text);
    if (profanityPhrases.contains(compact) || placeholders.contains(compact)) {
      return _fail(
        text,
        NameErrorCode.profanity,
        'This name contains language that isn’t allowed. '
        'Please enter your real name.',
      );
    }

    return NameValidation(sanitized: text);
  }

  static NameValidation _fail(
    String sanitized,
    NameErrorCode code,
    String message,
  ) {
    return NameValidation(sanitized: sanitized, code: code, error: message);
  }

  static bool _looksLikeMash(String token) {
    final lower = token.toLowerCase();
    if (_repeated.hasMatch(lower)) return true;
    if (lower.length >= 3) {
      final distinct = lower.split('').toSet().length;
      if (distinct <= 1) return true;
      if (lower.length >= 5 && distinct <= 2) return true;
    }
    if (_keyboardMash.hasMatch(lower) && lower.length <= 12) return true;
    if (_consonantRun.hasMatch(lower)) return true;
    return false;
  }

  static bool _isProfane(String folded) {
    if (profanity.contains(folded)) return true;
    // English inflection suffixes only; avoids substring false positives.
    for (final root in profanity) {
      if (folded == root) return true;
      if (folded.startsWith(root) &&
          const [
            's',
            'es',
            'ed',
            'ing',
            'er',
            'ers',
            'y',
          ].contains(folded.substring(root.length))) {
        return true;
      }
    }
    return false;
  }

  static String _fold(String value) {
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(_accentFold[char] ?? char);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'\p{M}', unicode: true), '')
        .replaceAll(RegExp(r"[^a-z']"), '');
  }

  static String _compact(String value) => _fold(value).replaceAll("'", '');

  static String _capWords(String value) {
    return value
        .split(' ')
        .map((token) => token.isEmpty ? token : _capToken(token))
        .join(' ');
  }

  static String _capToken(String token) {
    final isLower = token == token.toLowerCase();
    final isUpper = token == token.toUpperCase();
    if (!isLower && !isUpper) return token;
    return token.splitMapJoin(
      RegExp(r"[-']"),
      onMatch: (match) => match[0]!,
      onNonMatch: (part) => _capPart(part, isUpper: isUpper),
    );
  }

  static String _capPart(String part, {required bool isUpper}) {
    if (part.isEmpty) return part;
    final body = isUpper ? part.toLowerCase() : part;
    return body[0].toUpperCase() + body.substring(1);
  }

  /// Text input formatter that enforces the hard character budget without
  /// rewriting characters mid-edit (which would move the caret).
  static final List<TextInputFormatter> inputFormatters = [
    LengthLimitingTextInputFormatter(maxLength),
    FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
  ];
}
