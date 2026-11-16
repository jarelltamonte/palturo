import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remembers which For You cards a signed-in user has already swiped.
///
/// The deck itself stays server-ranked. This only filters the local view so a
/// relogin lands on the exhausted state instead of replaying seen cards.
class SeenDeckService {
  SeenDeckService._();

  static final SeenDeckService instance = SeenDeckService._();

  static const String _keyPrefix = 'deck_seen_v1_';
  static const int _maxIds = 1000;

  /// Test hook: when set, storage is scoped to this id instead of Supabase.
  @visibleForTesting
  String? userIdOverride;

  String? get _userId {
    if (userIdOverride != null) return userIdOverride;
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String? get _key {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return null;
    return '$_keyPrefix$userId';
  }

  String? _cachedKey;
  Set<String> _cache = <String>{};
  Future<void> _writeQueue = Future<void>.value();

  /// Loads the seen set for the current user. Safe to call on a cold boot and
  /// in tests where Supabase is not initialized.
  Future<Set<String>> load() async {
    final key = _key;
    if (key == null) return <String>{};
    if (_cachedKey == key) return Set<String>.of(_cache);
    try {
      final raw = await PreferencesService.instance.getString(key);
      final parsed = parse(raw);
      _cachedKey = key;
      _cache = parsed;
      return Set<String>.of(parsed);
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> markSeen(String personId) async {
    final key = _key;
    if (key == null || personId.isEmpty) return;
    if (_cachedKey != key) await load();
    if (_cache.add(personId)) await _persist();
  }

  Future<void> unmarkSeen(String personId) async {
    final key = _key;
    if (key == null || personId.isEmpty) return;
    if (_cachedKey != key) await load();
    if (_cache.remove(personId)) await _persist();
  }

  Future<void> _persist() {
    final key = _cachedKey;
    if (key == null) return Future<void>.value();
    var ids = _cache.toList();
    if (ids.length > _maxIds) {
      ids = ids.sublist(ids.length - _maxIds);
    }
    final payload = jsonEncode(ids);
    _writeQueue = _writeQueue
        .then((_) => PreferencesService.instance.setString(key, payload))
        .catchError((_) {});
    return _writeQueue;
  }

  @visibleForTesting
  static Set<String> parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.whereType<String>().where((id) => id.isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }
}
