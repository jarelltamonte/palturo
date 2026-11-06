import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/notification_service.dart';
import 'package:palturo/services/preferences_service.dart';

/// Keeps the launcher/app-icon badge in sync with unread messages + activity.
class AppBadgeService {
  AppBadgeService._();

  static final AppBadgeService instance = AppBadgeService._();

  bool _initialized = false;
  int _last = -1;
  Future<void> _writeQueue = Future.value();

  void init() {
    if (_initialized) return;
    _initialized = true;
    NotificationService.instance.addListener(_sync);
    ChatStateService.instance.addListener(_sync);
    PreferencesService.instance.addListener(_sync);
    _sync();
  }

  void _sync() {
    _setBadge(
      combinedBadgeCount(
        activityUnread: NotificationService.instance.unread,
        messageUnread: ChatStateService.instance.totalUnreadCount,
        enabled: PreferencesService.instance.notificationsEnabled,
      ),
    );
  }

  Future<void> _setBadge(int count) async {
    if (kIsWeb) return;
    final safe = count < 0 ? 0 : count;
    if (safe == _last) return;
    _last = safe;
    // Serialize writes so rapid unread changes cannot complete out of order.
    _writeQueue = _writeQueue.then((_) async {
      try {
        await AppBadgePlus.updateBadge(safe);
      } catch (_) {
        // Desktop/web/unsupported launchers simply ignore the badge.
      }
    });
    await _writeQueue;
  }

  void reset() {
    _last = -1;
    unawaited(_setBadge(0));
  }

  void dispose() {
    NotificationService.instance.removeListener(_sync);
    ChatStateService.instance.removeListener(_sync);
    PreferencesService.instance.removeListener(_sync);
  }
}

@visibleForTesting
int combinedBadgeCount({
  required int activityUnread,
  required int messageUnread,
  required bool enabled,
}) {
  if (!enabled) return 0;
  final total = activityUnread + messageUnread;
  return total < 0 ? 0 : total;
}
