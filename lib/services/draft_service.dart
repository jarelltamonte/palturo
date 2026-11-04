import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:palturo/services/preferences_service.dart';

/// Local-only unsent message drafts, keyed by connection id.
class DraftService extends ChangeNotifier {
  DraftService._();

  static final DraftService instance = DraftService._();

  static const _key = 'chat_drafts';

  final Map<String, String> _drafts = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await PreferencesService.instance.getString(_key);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final key = entry.key?.toString();
          final value = entry.value?.toString();
          if (key == null || key.isEmpty || value == null || value.isEmpty) {
            continue;
          }
          _drafts[key] = value;
        }
      }
    } catch (_) {
      // A malformed draft store must not block chat.
    }
    notifyListeners();
  }

  String? draftFor(String connectionId) {
    final value = _drafts[connectionId];
    return value == null || value.trim().isEmpty ? null : value;
  }

  bool hasDraft(String connectionId) => draftFor(connectionId) != null;

  Future<void> saveDraft(String connectionId, String text) async {
    if (text.trim().isEmpty) {
      await clearDraft(connectionId);
      return;
    }
    if (_drafts[connectionId] == text) return;
    _drafts[connectionId] = text;
    notifyListeners();
    await _persist();
  }

  Future<void> clearDraft(String connectionId) async {
    if (!_drafts.containsKey(connectionId)) return;
    _drafts.remove(connectionId);
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    if (_drafts.isEmpty) return;
    _drafts.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() {
    return PreferencesService.instance.setString(_key, jsonEncode(_drafts));
  }
}
