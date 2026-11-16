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
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/notification_service.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/services/sound_service.dart';
import 'package:palturo/widgets/app_banner.dart';
import 'package:palturo/widgets/match_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Decides which surface a live event uses and suppresses noise for the screen
/// the user is already on.
class NotificationPresenter {
  NotificationPresenter._();

  static final NotificationPresenter instance = NotificationPresenter._();

  static const _celebratedKey = 'celebrated_connections';

  final Set<String> _celebrated = <String>{};
  StreamSubscription<AppNotification>? _notificationSub;
  StreamSubscription<AppNotification>? _deletionSub;
  StreamSubscription<IncomingMessageEvent>? _messageSub;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    unawaited(_loadCelebrated());
    _notificationSub = NotificationService.instance.events.listen(
      _onNotification,
    );
    _deletionSub = NotificationService.instance.deletions.listen(_onDeleted);
    _messageSub = ChatStateService.instance.messageEvents.listen(_onMessage);
  }

  /// Shows the top match banner immediately (used by the accept flow and by
  /// the requester-side `request_accepted` event).
  void showMatch({
    required String connectionId,
    required String name,
    String? skillName,
    String? avatarUrl,
    Person? person,
    PersonRole? role,
    String? notificationId,
  }) {
    if (!PreferencesService.instance.notificationsEnabled) return;
    if (!PreferencesService.instance.requestNotificationsEnabled) return;
    if (!_markCelebrated(connectionId)) return;
    if (notificationFeedbackAllowed()) {
      unawaited(Haptics.match());
      unawaited(SoundService.instance.play(AppSound.match));
    }
    final data = buildMatchBanner(
      id: 'match:$connectionId',
      name: name.trim().isEmpty ? 'your Pal' : name,
      skillName: skillName,
      avatarUrl: avatarUrl,
      onSayHello: () {
        if (notificationId != null) {
          unawaited(NotificationService.instance.markItemRead(notificationId));
        }
        AppRouter.openChat(
          connectionId: connectionId,
          name: name,
          skillName: skillName,
          avatarUrl: avatarUrl,
          person: person,
          role: role,
        );
      },
    );
    AppBannerController.instance.show(data, preempt: true);
  }

  void _onNotification(AppNotification item) {
    unawaited(_presentNotification(item));
  }

  void _onDeleted(AppNotification item) {
    AppBannerController.instance.removeGroup(
      'notification:${item.kind.wireValue}:${item.connectionId ?? item.id}',
    );
  }

  Future<void> _presentNotification(AppNotification item) async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    if (!NotificationService.instance.isForeground) return;
    if (!PreferencesService.instance.notificationsEnabled) return;
    if (AppShellState.instance.activityOpen) return;
    if (item.kind == AppNotificationKind.unknown) return;
    if (!notificationKindEnabled(item.kind)) return;
    if (item.kind == AppNotificationKind.connectionRequest &&
        (AppShellState.instance.selectedTab == 3 ||
            AppShellState.instance.requestsOpen)) {
      return;
    }

    // The realtime row carries IDs only. Enrich it the same way Activity does
    // so the banner can name the person and skill.
    RequestLite? incoming;
    ConversationLite? conversation;
    if (item.kind == AppNotificationKind.connectionRequest) {
      incoming = await _findIncoming(item.connectionId);
    } else if (item.kind == AppNotificationKind.requestAccepted ||
        item.kind == AppNotificationKind.requestDeclined ||
        item.kind == AppNotificationKind.feedbackReady) {
      conversation = await _findConversation(item.connectionId);
    }

    // The user may have left, disabled notifications, or opened the relevant
    // screen while the enrichment call was in flight.
    if (Supabase.instance.client.auth.currentUser == null) return;
    if (!NotificationService.instance.isForeground) return;
    if (!PreferencesService.instance.notificationsEnabled) return;
    if (!notificationKindEnabled(item.kind)) return;
    if (AppShellState.instance.activityOpen) return;
    if (item.kind == AppNotificationKind.connectionRequest &&
        (AppShellState.instance.selectedTab == 3 ||
            AppShellState.instance.requestsOpen)) {
      return;
    }

    final view = presentActivity(
      item.toRow(),
      incoming: incoming,
      conversation: conversation,
    );
    final enriched = item.copyWith(
      actorName: view.actorName,
      actorAvatar:
          item.actorAvatar ?? conversation?.otherAvatar ?? incoming?.avatarUrl,
      skillName: view.skillName,
      role: item.role ?? conversation?.otherRole,
    );

    if (item.kind == AppNotificationKind.requestAccepted) {
      final connectionId = enriched.connectionId;
      if (connectionId == null) {
        _showStandard(enriched, view);
        return;
      }
      if (ChatStateService.instance.activeConnectionId == connectionId) {
        _markCelebrated(connectionId);
        return;
      }
      final avatarUrl = enriched.actorAvatar;
      final role = _roleFrom(enriched.role);
      showMatch(
        connectionId: connectionId,
        name: view.actorName ?? 'your Pal',
        skillName: view.skillName,
        avatarUrl: avatarUrl,
        role: role,
        notificationId: enriched.id,
        person: _personFor(
          id: enriched.actorId,
          name: view.actorName ?? 'Pal',
          skillName: view.skillName,
          avatarUrl: avatarUrl,
          role: role,
        ),
      );
      return;
    }

    if (item.kind == AppNotificationKind.feedbackReady &&
        ChatStateService.instance.activeConnectionId == enriched.connectionId) {
      return;
    }

    _showStandard(enriched, view);
  }

  Future<RequestLite?> _findIncoming(String? connectionId) async {
    if (connectionId == null) return null;
    try {
      final rows = await MatchApi.getIncomingRequests();
      for (final row in rows) {
        if (row.connectionId == connectionId) return row;
      }
    } catch (_) {
      // Enrichment is best-effort; the banner falls back to generic copy.
    }
    return null;
  }

  Future<ConversationLite?> _findConversation(String? connectionId) async {
    if (connectionId == null) return null;
    try {
      final rows = await MatchApi.getConversations();
      for (final row in rows) {
        if (row.connectionId == connectionId) return row;
      }
    } catch (_) {
      // Enrichment is best-effort; the banner falls back to generic copy.
    }
    return null;
  }

  void _showStandard(AppNotification item, ActivityItemView view) {
    if (notificationFeedbackAllowed()) {
      if (item.kind == AppNotificationKind.connectionRequest) {
        unawaited(Haptics.impact());
      } else if (item.kind == AppNotificationKind.requestDeclined) {
        unawaited(Haptics.warning());
      } else if (item.kind == AppNotificationKind.feedbackReady) {
        unawaited(Haptics.success());
        unawaited(SoundService.instance.play(AppSound.success));
      } else if (item.kind == AppNotificationKind.skillModeration) {
        unawaited(Haptics.selection());
      }
    }
    final rawTap = _tapFor(item, view);
    VoidCallback? readThen(VoidCallback? action) {
      if (action == null) return null;
      return () {
        unawaited(NotificationService.instance.markItemRead(item.id));
        action();
      };
    }

    final onTap = readThen(rawTap);
    final String? actionLabel;
    final VoidCallback? onAction;
    if (item.kind == AppNotificationKind.skillModeration) {
      actionLabel = 'Review';
      onAction = readThen(() => AppRouter.openProfile());
    } else if (rawTap != null && view.actionLabel.isNotEmpty) {
      actionLabel = view.actionLabel;
      onAction = readThen(rawTap);
    } else {
      actionLabel = null;
      onAction = null;
    }
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
        onAction: onAction,
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
          person: _personFor(
            id: item.actorId,
            name: view.actorName ?? 'Pal',
            skillName: view.skillName,
            avatarUrl: item.actorAvatar,
            role: _roleFrom(item.role),
          ),
        );
      case ActivityDestination.none:
        if (item.kind == AppNotificationKind.skillModeration) {
          return () => AppRouter.openProfile();
        }
        return null;
    }
  }

  void _onMessage(IncomingMessageEvent event) {
    if (Supabase.instance.client.auth.currentUser == null) return;
    if (!PreferencesService.instance.notificationsEnabled) return;
    if (!PreferencesService.instance.messageNotificationsEnabled) return;
    if (!NotificationService.instance.isForeground) return;
    if (ChatStateService.instance.activeConnectionId == event.connectionId) {
      return;
    }
    if (ChatStateService.instance.isMuted(event.connectionId)) return;

    if (notificationFeedbackAllowed()) {
      unawaited(Haptics.tap());
      unawaited(SoundService.instance.play(AppSound.message));
    }
    final body = messageBannerBody(event);
    final role = _roleFrom(event.role);
    AppBannerController.instance.showOrUpdate(
      AppBannerData(
        id:
            'message:${event.connectionId}:'
            '${event.createdAt.millisecondsSinceEpoch}',
        groupKey: 'chat:${event.connectionId}',
        title: event.senderName,
        body: body,
        icon: CupertinoIcons.chat_bubble,
        avatarUrl: event.avatarUrl,
        actorName: event.senderName,
        onTap:
            () => AppRouter.openChat(
              connectionId: event.connectionId,
              name: event.senderName,
              skillName: event.skillName,
              role: role,
              avatarUrl: event.avatarUrl,
              person: _personFor(
                id: event.peerUserId,
                name: event.senderName,
                skillName: event.skillName,
                avatarUrl: event.avatarUrl,
                role: role,
              ),
            ),
      ),
    );
  }

  Person? _personFor({
    required String? id,
    required String name,
    String? skillName,
    String? avatarUrl,
    PersonRole? role,
  }) {
    final userId = id?.trim();
    if (userId == null || userId.isEmpty) return null;
    return Person(
      id: userId,
      name: name,
      schedule: '',
      language: '',
      learningStyle: '',
      skillName: skillName ?? '',
      role: role ?? PersonRole.mentor,
      photoUrls: [avatarUrl],
    );
  }

  /// Clears transient UI state on sign-out. Celebrations are account-scoped.
  void reset() {
    AppBannerController.instance.clear();
    _celebrated.clear();
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
    _deletionSub?.cancel();
    _messageSub?.cancel();
    AppBannerController.instance.clear();
  }
}

bool notificationKindEnabled(AppNotificationKind kind) {
  switch (kind) {
    case AppNotificationKind.connectionRequest:
    case AppNotificationKind.requestAccepted:
    case AppNotificationKind.requestDeclined:
      return PreferencesService.instance.requestNotificationsEnabled;
    case AppNotificationKind.feedbackReady:
    case AppNotificationKind.skillModeration:
      return PreferencesService.instance.activityNotificationsEnabled;
    case AppNotificationKind.unknown:
      return false;
  }
}

@visibleForTesting
String messageBannerBody(IncomingMessageEvent event) {
  return PreferencesService.instance.messagePreviewsEnabled
      ? event.preview
      : 'New message';
}

@visibleForTesting
bool notificationFeedbackAllowed({DateTime? now}) {
  return !PreferencesService.instance.isQuietHours(now ?? DateTime.now());
}
