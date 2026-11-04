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
  bool _loadFailed = false;
  int _generation = 0;
  Future<bool>? _inflightLoad;

  bool get loaded => _loaded;
  bool get loading => _loading;
  bool get loadFailed => _loadFailed;

  Future<void> loadIfNeeded() async {
    if (_loaded || _loading) return;
    await load();
  }

  Future<bool> load() {
    if (_loaded) return Future.value(true);
    final existing = _inflightLoad;
    if (existing != null) return existing;
    final future = _doLoad();
    _inflightLoad = future;
    return future.whenComplete(() {
      if (identical(_inflightLoad, future)) _inflightLoad = null;
    });
  }

  Future<bool> _doLoad() async {
    final generation = _generation;
    _loading = true;
    _loadFailed = false;
    notifyListeners();
    try {
      final data = await MatchApi.getChatPrivacy();
      if (generation != _generation) return false;
      presenceEnabled = data['presence_enabled'] != false;
      typingEnabled = data['typing_enabled'] != false;
      readReceiptsEnabled = data['read_receipts_enabled'] != false;
      _loaded = true;
      _loadFailed = false;
      return true;
    } catch (_) {
      if (generation != _generation) return false;
      // Stay unloaded so the page cannot save stale defaults.
      _loadFailed = true;
      return false;
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save({
    required bool presence,
    required bool typing,
    required bool readReceipts,
  }) async {
    final generation = _generation;
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
      if (generation != _generation) return false;
      _loaded = true;
      return true;
    } catch (_) {
      if (generation != _generation) return false;
      presenceEnabled = previous.$1;
      typingEnabled = previous.$2;
      readReceiptsEnabled = previous.$3;
      notifyListeners();
      return false;
    }
  }

  @visibleForTesting
  void debugSetLoaded({
    bool presence = true,
    bool typing = true,
    bool readReceipts = true,
  }) {
    presenceEnabled = presence;
    typingEnabled = typing;
    readReceiptsEnabled = readReceipts;
    _loaded = true;
    _loading = false;
    _loadFailed = false;
    notifyListeners();
  }

  void reset() {
    _generation++;
    _inflightLoad = null;
    presenceEnabled = true;
    typingEnabled = true;
    readReceiptsEnabled = true;
    _loaded = false;
    _loading = false;
    _loadFailed = false;
    notifyListeners();
  }
}
