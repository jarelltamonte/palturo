import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:palturo/models/app_notification.dart';
import 'package:palturo/models/incoming_message_event.dart';
import 'package:palturo/screen/activity_presentation.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/request_page.dart';
import 'package:palturo/services/app_navigation.dart';
import 'package:palturo/services/app_shell_state.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/notification_service.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/widgets/app_banner.dart';
import 'package:palturo/widgets/match_banner.dart';

/// Decides which surface a live event uses and suppresses noise for the screen
/// the user is already on.
class NotificationPresenter {
  NotificationPresenter._();

  static final NotificationPresenter instance = NotificationPresenter._();

  static const _celebratedKey = 'celebrated_connections';

  final Set<String> _celebrated = <String>{};
  StreamSubscription<AppNotification>? _notificationSub;
  StreamSubscription<IncomingMessageEvent>? _messageSub;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    unawaited(_loadCelebrated());
    _notificationSub = NotificationService.instance.events.listen(
      _onNotification,
    );
    _messageSub = ChatStateService.instance.messageEvents.listen(_onMessage);
  }

  /// Shows the top match banner immediately (used by the accept flow and by
  /// the requester-side `request_accepted` event).
  void showMatch({
    required String connectionId,
    required String name,
    String? skillName,
    String? avatarUrl,
  }) {
    if (!_markCelebrated(connectionId)) return;
    final data = buildMatchBanner(
      id: 'match:$connectionId',
      name: name.trim().isEmpty ? 'your Pal' : name,
      skillName: skillName,
      avatarUrl: avatarUrl,
      onSayHello:
          () => AppRouter.openChat(
            connectionId: connectionId,
            name: name,
            skillName: skillName,
            avatarUrl: avatarUrl,
          ),
    );
    AppBannerController.instance.show(data, preempt: true);
  }

  void _onNotification(AppNotification item) {
    if (!PreferencesService.instance.notificationsEnabled) {
      return;
    }
    if (AppShellState.instance.activityOpen) {
      return;
    }
    if (item.kind == AppNotificationKind.unknown) return;

    final view = presentActivity(item.toRow());
    if (item.kind == AppNotificationKind.connectionRequest &&
        AppShellState.instance.selectedTab == 3) {
      return;
    }

    if (item.kind == AppNotificationKind.requestAccepted) {
      final connectionId = item.connectionId;
      if (connectionId == null) {
        _showStandard(item, view);
        return;
      }
      if (ChatStateService.instance.activeConnectionId == connectionId) {
        _markCelebrated(connectionId);
        return;
      }
      showMatch(
        connectionId: connectionId,
        name: view.actorName ?? 'your Pal',
        skillName: view.skillName,
        avatarUrl: item.actorAvatar,
      );
      return;
    }

    if (item.kind == AppNotificationKind.feedbackReady &&
        ChatStateService.instance.activeConnectionId == item.connectionId) {
      return;
    }

    _showStandard(item, view);
  }

  void _showStandard(AppNotification item, ActivityItemView view) {
    final onTap = _tapFor(item, view);
    final actionLabel =
        item.kind == AppNotificationKind.skillModeration
            ? 'Review'
            : view.actionLabel.isEmpty
            ? null
            : view.actionLabel;
    AppBannerController.instance.show(
      AppBannerData(
        id: item.id,
        groupKey:
            'notification:${item.kind.wireValue}:'
            '${item.connectionId ?? item.id}',
        title: view.title,
        body: view.body,
        icon: view.icon,
        avatarUrl: item.actorAvatar,
        actorName: item.actorName,
        actionLabel: actionLabel,
        onTap: onTap,
        onAction:
            item.kind == AppNotificationKind.skillModeration
                ? () => AppRouter.openProfile()
                : null,
      ),
    );
  }

  VoidCallback? _tapFor(AppNotification item, ActivityItemView view) {
    switch (view.destination) {
      case ActivityDestination.incomingRequests:
        return () => AppRouter.openRequests();
      case ActivityDestination.sentRequests:
        return () => AppRouter.openRequests(view: RequestView.sent);
      case ActivityDestination.chat:
        final connectionId = view.connectionId;
        if (connectionId == null) return null;
        return () => AppRouter.openChat(
          connectionId: connectionId,
          name: view.actorName ?? 'Pal',
          skillName: view.skillName,
          role: _roleFrom(item.role),
          avatarUrl: item.actorAvatar,
        );
      case ActivityDestination.none:
        if (item.kind == AppNotificationKind.skillModeration) {
          return () => AppRouter.openProfile();
        }
        return null;
    }
  }

  void _onMessage(IncomingMessageEvent event) {
    if (!PreferencesService.instance.notificationsEnabled) return;
    if (!NotificationService.instance.isForeground) return;
    if (ChatStateService.instance.activeConnectionId == event.connectionId) {
      return;
    }

    AppBannerController.instance.showOrUpdate(
      AppBannerData(
        id:
            'message:${event.connectionId}:'
            '${event.createdAt.millisecondsSinceEpoch}',
        groupKey: 'chat:${event.connectionId}',
        title: event.senderName,
        body: event.preview,
        icon: CupertinoIcons.chat_bubble,
        avatarUrl: event.avatarUrl,
        actorName: event.senderName,
        onTap:
            () => AppRouter.openChat(
              connectionId: event.connectionId,
              name: event.senderName,
              skillName: event.skillName,
              role: _roleFrom(event.role),
              avatarUrl: event.avatarUrl,
            ),
      ),
    );
  }

  PersonRole? _roleFrom(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'learner':
        return PersonRole.learner;
      case 'mentor':
        return PersonRole.mentor;
      default:
        return null;
    }
  }

  Future<void> _loadCelebrated() async {
    try {
      final raw = await PreferencesService.instance.getString(_celebratedKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _celebrated.addAll(decoded.whereType<String>());
      }
    } catch (_) {
      // A malformed list must not block banners.
    }
  }

  bool _markCelebrated(String connectionId) {
    if (_celebrated.contains(connectionId)) return false;
    _celebrated.add(connectionId);
    if (_celebrated.length > 100) {
      _celebrated.remove(_celebrated.first);
    }
    unawaited(
      PreferencesService.instance.setString(
        _celebratedKey,
        jsonEncode(_celebrated.toList(growable: false)),
      ),
    );
    return true;
  }

  void dispose() {
    _notificationSub?.cancel();
    _messageSub?.cancel();
    AppBannerController.instance.clear();
  }
}
