import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:palturo/models/app_notification.dart';
import 'package:palturo/models/incoming_message_event.dart';
import 'package:palturo/screen/activity_presentation.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/request_page.dart';
import 'package:palturo/services/app_navigation.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/notification_presenter.dart';
import 'package:palturo/services/notification_service.dart';
import 'package:palturo/services/preferences_service.dart';

enum NotificationPermissionStatus { unknown, granted, denied, unsupported }

/// Local system notifications for backgrounded mobile/web sessions.
///
/// Foreground events stay in the in-app banner presenter; this service only
/// presents when the app is not resumed. Push (A5) will reuse the same payload
/// contract.
class LocalNotificationService extends ChangeNotifier {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const _messagesChannel = AndroidNotificationChannel(
    'palturo_messages',
    'Messages',
    description: 'New messages from your Pals',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  static const _requestsChannel = AndroidNotificationChannel(
    'palturo_requests',
    'Requests & matches',
    description: 'New requests, accepted requests, and declines',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  static const _activityChannel = AndroidNotificationChannel(
    'palturo_activity',
    'Activity updates',
    description: 'Feedback reminders and skill moderation updates',
    importance: Importance.defaultImportance,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<AppNotification>? _notificationSub;
  StreamSubscription<IncomingMessageEvent>? _messageSub;
  bool _initialized = false;
  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.unknown;

  NotificationPermissionStatus get permissionStatus => _permissionStatus;

  bool get isPermissionGranted =>
      _permissionStatus == NotificationPermissionStatus.granted;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_palturo'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      web: WebInitializationSettings(),
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onResponse,
      );
    } catch (_) {
      // Local notifications are best-effort; the in-app banner still works.
      return;
    }

    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android != null) {
      try {
        await android.createNotificationChannel(_messagesChannel);
        await android.createNotificationChannel(_requestsChannel);
        await android.createNotificationChannel(_activityChannel);
      } catch (_) {}
    }

    await refreshPermissionStatus();
    _notificationSub = NotificationService.instance.events.listen(
      _onNotification,
    );
    _messageSub = ChatStateService.instance.messageEvents.listen(_onMessage);

    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final payload = launch?.notificationResponse?.payload;
        if (payload != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handlePayload(payload);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> refreshPermissionStatus() async {
    var next = NotificationPermissionStatus.unknown;
    try {
      if (kIsWeb) {
        final web =
            _plugin
                .resolvePlatformSpecificImplementation<
                  WebFlutterLocalNotificationsPlugin
                >();
        switch (web?.permissionStatus) {
          case WebNotificationPermission.granted:
            next = NotificationPermissionStatus.granted;
          case WebNotificationPermission.denied:
            next = NotificationPermissionStatus.denied;
          case WebNotificationPermission.defaultPermissions:
            next = NotificationPermissionStatus.unknown;
          case null:
            next = NotificationPermissionStatus.unsupported;
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android =
            _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        final enabled = await android?.areNotificationsEnabled();
        next =
            enabled == true
                ? NotificationPermissionStatus.granted
                : enabled == false
                ? NotificationPermissionStatus.denied
                : NotificationPermissionStatus.unknown;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios =
            _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
        final options = await ios?.checkPermissions();
        next =
            options?.isEnabled == true
                ? NotificationPermissionStatus.granted
                : options?.isEnabled == false
                ? NotificationPermissionStatus.denied
                : NotificationPermissionStatus.unknown;
      } else {
        next = NotificationPermissionStatus.unsupported;
      }
    } catch (_) {
      next = NotificationPermissionStatus.unknown;
    }
    if (_permissionStatus == next) return;
    _permissionStatus = next;
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    var granted = false;
    try {
      if (kIsWeb) {
        final web =
            _plugin
                .resolvePlatformSpecificImplementation<
                  WebFlutterLocalNotificationsPlugin
                >();
        granted = await web?.requestNotificationsPermission() ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android =
            _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        granted = await android?.requestNotificationsPermission() ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios =
            _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
        granted =
            await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (_) {
      granted = false;
    }
    _permissionStatus =
        granted
            ? NotificationPermissionStatus.granted
            : NotificationPermissionStatus.denied;
    notifyListeners();
    return granted;
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  void _onNotification(AppNotification item) {
    if (NotificationService.instance.isForeground) return;
    if (!PreferencesService.instance.notificationsEnabled) return;
    if (PreferencesService.instance.isQuietHoursNow) return;
    if (item.kind == AppNotificationKind.unknown) return;
    if (!notificationKindEnabled(item.kind)) return;

    final view = presentActivity(item.toRow());
    final channel = _channelFor(item.kind);
    _show(
      id: item.id,
      title: view.title,
      body: view.body,
      channel: channel,
      payload: _payloadForNotification(item, view),
      threadId: item.connectionId,
    );
  }

  void _onMessage(IncomingMessageEvent event) {
    if (NotificationService.instance.isForeground) return;
    if (!PreferencesService.instance.notificationsEnabled) return;
    if (!PreferencesService.instance.messageNotificationsEnabled) return;
    if (PreferencesService.instance.isQuietHoursNow) return;

    final body =
        PreferencesService.instance.messagePreviewsEnabled
            ? event.preview
            : 'New message';
    _show(
      id:
          'message:${event.connectionId}:${event.createdAt.microsecondsSinceEpoch}',
      title: event.senderName,
      body: body,
      channel: _messagesChannel,
      payload: {
        'route': 'chat',
        'connectionId': event.connectionId,
        'name': event.senderName,
        'skillName': event.skillName,
        'role': event.role,
        'avatarUrl': event.avatarUrl,
      },
      threadId: event.connectionId,
    );
  }

  void _show({
    required String id,
    required String title,
    required String body,
    required AndroidNotificationChannel channel,
    required Map<String, dynamic> payload,
    String? threadId,
  }) {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.high,
        icon: 'ic_stat_palturo',
        styleInformation: BigTextStyleInformation(body),
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: threadId,
      ),
      web: WebNotificationDetails(iconUrl: Uri.parse('icons/Icon-192.png')),
    );
    unawaited(
      _plugin.show(
        id: _notificationId(id),
        title: title,
        body: body,
        notificationDetails: details,
        payload: jsonEncode(payload),
      ),
    );
  }

  AndroidNotificationChannel _channelFor(AppNotificationKind kind) {
    switch (kind) {
      case AppNotificationKind.connectionRequest:
      case AppNotificationKind.requestAccepted:
      case AppNotificationKind.requestDeclined:
        return _requestsChannel;
      case AppNotificationKind.feedbackReady:
      case AppNotificationKind.skillModeration:
        return _activityChannel;
      case AppNotificationKind.unknown:
        return _activityChannel;
    }
  }

  Map<String, dynamic> _payloadForNotification(
    AppNotification item,
    ActivityItemView view,
  ) {
    switch (view.destination) {
      case ActivityDestination.incomingRequests:
        return {'route': 'requests', 'view': 'incoming'};
      case ActivityDestination.sentRequests:
        return {'route': 'requests', 'view': 'sent'};
      case ActivityDestination.chat:
        return {
          'route': 'chat',
          'connectionId': view.connectionId,
          'name': view.actorName,
          'skillName': view.skillName,
          'role': item.role,
          'avatarUrl': item.actorAvatar,
        };
      case ActivityDestination.none:
        return item.kind == AppNotificationKind.skillModeration
            ? {'route': 'profile'}
            : {'route': 'activity'};
    }
  }

  void _onResponse(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  void _handlePayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) return;
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    final route = payload['route']?.toString();
    switch (route) {
      case 'chat':
        final connectionId = payload['connectionId']?.toString();
        if (connectionId == null || connectionId.isEmpty) {
          unawaited(AppRouter.openActivity());
          return;
        }
        unawaited(
          AppRouter.openChat(
            connectionId: connectionId,
            name: payload['name']?.toString() ?? 'Pal',
            skillName: payload['skillName']?.toString(),
            role: _roleFrom(payload['role']?.toString()),
            avatarUrl: payload['avatarUrl']?.toString(),
          ),
        );
      case 'requests':
        unawaited(
          AppRouter.openRequests(
            view:
                payload['view']?.toString() == 'sent'
                    ? RequestView.sent
                    : RequestView.incoming,
          ),
        );
      case 'profile':
        unawaited(AppRouter.openProfile());
      case 'activity':
      default:
        unawaited(AppRouter.openActivity());
    }
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

  @visibleForTesting
  int notificationIdFor(String key) => _notificationId(key);

  @visibleForTesting
  Map<String, dynamic> payloadFor(AppNotification item) {
    return _payloadForNotification(item, presentActivity(item.toRow()));
  }

  int _notificationId(String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _messageSub?.cancel();
    super.dispose();
  }
}
