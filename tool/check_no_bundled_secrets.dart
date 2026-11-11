import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Fails when a built Flutter artifact contains a bundled env file or a
/// credential-shaped value.
///
/// Usage:
///   dart run tool/check_no_bundled_secrets.dart [directory]
///
/// With no argument it requires at least one packaged release output
/// (`build/app/outputs`, `build/web`, or an iOS build) and also scans
/// `build/flutter_assets` when present. Compiled `--dart-define` values live
/// in libapp.so / main.dart.js, so scanning only flutter_assets is not enough.
/// APK/AAB/IPA/ZIP/JAR archives are decompressed and their entries scanned.
void main(List<String> args) {
  final asciiPatterns = <RegExp>[
    RegExp(r'sbp_[A-Za-z0-9]{20,}'),
    RegExp(r'SUPABASE_PAT(?!\w)'),
    RegExp(r'SUPABASE_SERVICE_ROLE_KEY(?!\w)'),
  ];
  final utf16Markers = <String>[
    'sbp_',
    'SUPABASE_PAT',
    'SUPABASE_SERVICE_ROLE_KEY',
  ];
  final findings = <String>[];

  if (args.isNotEmpty && File(args.first).existsSync()) {
    _scanOne(File(args.first), findings, asciiPatterns, utf16Markers);
    _report(findings);
    return;
  }

  final List<Directory> targets;

  if (args.isEmpty) {
    final releaseTargets = [
      Directory('build/app/outputs'),
      Directory('build/web'),
      Directory('build/ios/iphoneos'),
      Directory('build/ios/archive'),
    ].where((directory) => directory.existsSync() && _hasFiles(directory)).toList();

    if (releaseTargets.isEmpty) {
      stderr.writeln(
        'No packaged release artifact found. Build an APK/AAB, web bundle, or '
        'iOS app first, or pass an artifact directory explicitly.',
      );
      exitCode = 2;
      return;
    }

    targets = [
      ...releaseTargets,
      if (Directory('build/flutter_assets').existsSync())
        Directory('build/flutter_assets'),
    ];
  } else {
    final target = Directory(args.first);
    if (!target.existsSync()) {
      stderr.writeln('No artifact directory at ${target.path}.');
      exitCode = 2;
      return;
    }
    targets = [target];
  }

  for (final target in targets) {
    for (final entity in target.listSync(recursive: true, followLinks: false)) {
      if (entity is Link) {
        findings.add('${entity.path}: symlink in artifact tree');
        continue;
      }
      if (entity is File) {
        _scanOne(entity, findings, asciiPatterns, utf16Markers);
      }
    }
  }

  _report(findings);
}

bool _hasFiles(Directory directory) {
  return directory
      .listSync(recursive: true, followLinks: false)
      .any((entity) => entity is File || entity is Link);
}

void _scanOne(
  File file,
  List<String> findings,
  List<RegExp> asciiPatterns,
  List<String> utf16Markers,
) {
  final name = file.uri.pathSegments.last.toLowerCase();
  if (name == '.env' || name.startsWith('.env.')) {
    findings.add('${file.path}: environment file must not be bundled');
  }

  final hit = _isArchive(name)
      ? _scanArchive(file, asciiPatterns, utf16Markers)
      : _scanFile(file, asciiPatterns, utf16Markers);
  if (hit != null) {
    findings.add('${file.path}: $hit');
  }
}

void _report(List<String> findings) {
  if (findings.isEmpty) {
    stdout.writeln('PASS: no bundled env file or secret-shaped value found.');
    exitCode = 0;
    return;
  }

  stderr.writeln('FAIL: possible bundled secret material:');
  for (final finding in findings) {
    stderr.writeln(' - $finding');
  }
  stderr.writeln('Do not ship this artifact. Rotate any exposed credential.');
  exitCode = 1;
}

bool _isArchive(String name) {
  for (final extension in const ['.apk', '.aab', '.zip', '.ipa', '.jar', '.war']) {
    if (name.endsWith(extension)) return true;
  }
  return false;
}

String? _scanArchive(
  File file,
  List<RegExp> asciiPatterns,
  List<String> utf16Markers,
) {
  late final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(file.readAsBytesSync(), verify: false);
  } catch (_) {
    return 'unreadable archive; inspect it manually';
  }

  for (final entry in archive.files) {
    if (!entry.isFile) continue;
    final name = entry.name.toLowerCase();
    if (name == '.env' ||
        name.endsWith('/.env') ||
        name.contains('/.env.')) {
      return 'archive entry ${entry.name} is an environment file';
    }
    final hit = _scanBytes(
      Uint8List.fromList(entry.content),
      asciiPatterns,
      utf16Markers,
    );
    if (hit != null) return 'archive entry ${entry.name} matches $hit';
  }
  return null;
}

String? _scanFile(
  File file,
  List<RegExp> asciiPatterns,
  List<String> utf16Markers,
) {
  RandomAccessFile? reader;
  try {
    reader = file.openSync();
  } catch (_) {
    return 'unreadable file';
  }

  const chunkSize = 1024 * 1024;
  const overlap = 256;
  var carry = Uint8List(0);

  try {
    while (true) {
      final chunk = reader.readSync(chunkSize);
      final data = _concat(carry, chunk);
      final hit = _scanBytes(data, asciiPatterns, utf16Markers);
      if (hit != null) return 'matches $hit';

      if (chunk.isEmpty) break;
      final keep = data.length < overlap ? data.length : overlap;
      carry = Uint8List.fromList(data.sublist(data.length - keep));
    }
  } finally {
    reader.closeSync();
  }
  return null;
}

String? _scanBytes(
  Uint8List data,
  List<RegExp> asciiPatterns,
  List<String> utf16Markers,
) {
  final latin = latin1.decode(data, allowInvalid: true);
  for (final pattern in asciiPatterns) {
    if (pattern.hasMatch(latin)) return pattern.pattern;
  }
  for (final marker in utf16Markers) {
    if (_containsUtf16(data, marker)) return '$marker (UTF-16)';
  }
  return null;
}

Uint8List _concat(Uint8List left, Uint8List right) {
  if (left.isEmpty) return right;
  final builder = BytesBuilder(copy: false);
  builder.add(left);
  builder.add(right);
  return builder.takeBytes();
}

bool _containsUtf16(Uint8List haystack, String marker) {
  return _containsBytes(haystack, _utf16le(marker)) ||
      _containsBytes(haystack, _utf16be(marker));
}

bool _containsBytes(Uint8List haystack, List<int> needle) {
  if (needle.isEmpty || haystack.length < needle.length) return false;
  final first = needle[0];
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    if (haystack[i] != first) continue;
    var matched = true;
    for (var j = 1; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}

List<int> _utf16le(String value) {
  final bytes = <int>[];
  for (final unit in value.codeUnits) {
    bytes
      ..add(unit & 0xff)
      ..add((unit >> 8) & 0xff);
  }
  return bytes;
}

List<int> _utf16be(String value) {
  final bytes = <int>[];
  for (final unit in value.codeUnits) {
    bytes
      ..add((unit >> 8) & 0xff)
      ..add(unit & 0xff);
  }
  return bytes;
}
