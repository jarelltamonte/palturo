import 'package:flutter/foundation.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remembers whether the one-time For You card guide has been completed.
///
/// The flag is per account so a new account on the same device still gets the
/// tour. The guide is also suppressed when the local seen-deck already has
/// cards, which avoids surprising existing users after an app update.
class CardGuideService {
  CardGuideService._();

  static final CardGuideService instance = CardGuideService._();

  static const String _keyPrefix = 'card_guide_seen_v1_';

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

  Future<bool> shouldShow(Set<String> seenCards) async {
    if (seenCards.isNotEmpty) return false;
    final key = _key;
    if (key == null) return false;
    try {
      final seen = await PreferencesService.instance.getBool(key) ?? false;
      return !seen;
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    final key = _key;
    if (key == null) return;
    try {
      await PreferencesService.instance.setBool(key, true);
    } catch (_) {
      // The next card can retry; a storage failure must not break the deck.
    }
  }

  @visibleForTesting
  String? keyForTesting() => _key;
}
