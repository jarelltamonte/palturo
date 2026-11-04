import 'package:flutter/foundation.dart';
import 'package:palturo/services/match_api.dart';

/// Server-backed chat privacy switches (presence, typing, read receipts).
class ChatPrivacyService extends ChangeNotifier {
  ChatPrivacyService._();

  static final ChatPrivacyService instance = ChatPrivacyService._();

  bool presenceEnabled = true;
  bool typingEnabled = true;
  bool readReceiptsEnabled = true;
  bool _loaded = false;
  bool _loading = false;

  bool get loaded => _loaded;

  Future<void> loadIfNeeded() async {
    if (_loaded || _loading) return;
    await load();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await MatchApi.getChatPrivacy();
      presenceEnabled = data['presence_enabled'] != false;
      typingEnabled = data['typing_enabled'] != false;
      readReceiptsEnabled = data['read_receipts_enabled'] != false;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Keep the permissive defaults; the chat surfaces remain usable.
    } finally {
      _loading = false;
    }
  }

  Future<bool> save({
    required bool presence,
    required bool typing,
    required bool readReceipts,
  }) async {
    final previous = (presenceEnabled, typingEnabled, readReceiptsEnabled);
    presenceEnabled = presence;
    typingEnabled = typing;
    readReceiptsEnabled = readReceipts;
    notifyListeners();
    try {
      await MatchApi.setChatPrivacy(
        presence: presence,
        typing: typing,
        readReceipts: readReceipts,
      );
      _loaded = true;
      return true;
    } catch (_) {
      presenceEnabled = previous.$1;
      typingEnabled = previous.$2;
      readReceiptsEnabled = previous.$3;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    presenceEnabled = true;
    typingEnabled = true;
    readReceiptsEnabled = true;
    _loaded = false;
  }
}
