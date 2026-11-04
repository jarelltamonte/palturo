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
class LocalNotificationService extends ChangeNotifier
    with WidgetsBindingObserver {
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
      final initialized = await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onResponse,
      );
      if (initialized == false) {
        _initialized = false;
        return;
      }
    } catch (_) {
      // Local notifications are best-effort; the in-app banner still works.
      _initialized = false;
      return;
    }
    WidgetsBinding.instance.addObserver(this);

    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android != null) {
      try {
        await _createChannels(android);
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

  @visibleForTesting
  NotificationPermissionStatus resolvePermissionStatus({
    required bool? enabled,
    required bool asked,
  }) {
    if (enabled == true) return NotificationPermissionStatus.granted;
    if (enabled == false) {
      return asked
          ? NotificationPermissionStatus.denied
          : NotificationPermissionStatus.unknown;
    }
    return NotificationPermissionStatus.unknown;
  }

  Future<void> refreshPermissionStatus() async {
    var next = NotificationPermissionStatus.unknown;
    final asked =
        await PreferencesService.instance.getBool(
          'notification_permission_asked',
        ) ??
        false;
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
        next = resolvePermissionStatus(enabled: enabled, asked: asked);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios =
            _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
        final options = await ios?.checkPermissions();
        next = resolvePermissionStatus(
          enabled: options?.isEnabled,
          asked: asked,
        );
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
    unawaited(
      PreferencesService.instance.setBool(
        'notification_permission_asked',
        true,
      ),
    );
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

  Future<void> openSettings() async {
    if (kIsWeb) return;
    try {
      await _plugin.openAppNotificationSettings();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshPermissionStatus());
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  void _onNotification(AppNotification item) {
    if (NotificationService.instance.isForeground) return;
    if (!PreferencesService.instance.notificationsEnabled) return;
    if (item.kind == AppNotificationKind.unknown) return;
    if (!notificationKindEnabled(item.kind)) return;

    final quiet = PreferencesService.instance.isQuietHoursNow;
    final sound = PreferencesService.instance.soundEnabled && !quiet;
    final vibration = PreferencesService.instance.vibrationEnabled && !quiet;
    final view = presentActivity(item.toRow());
    _show(
      id: item.id,
      title: view.title,
      body: view.body,
      channel: _channelFor(item.kind, sound: sound, vibration: vibration),
      payload: _payloadForNotification(item, view),
      threadId: item.connectionId,
      quiet: quiet,
      sound: sound,
      vibration: vibration,
    );
  }

  void _onMessage(IncomingMessageEvent event) {
    if (NotificationService.instance.isForeground) return;
    if (!PreferencesService.instance.notificationsEnabled) return;
    if (!PreferencesService.instance.messageNotificationsEnabled) return;
    if (ChatStateService.instance.isMuted(event.connectionId)) return;

    final quiet = PreferencesService.instance.isQuietHoursNow;
    final sound = PreferencesService.instance.soundEnabled && !quiet;
    final vibration = PreferencesService.instance.vibrationEnabled && !quiet;
    final body =
        PreferencesService.instance.messagePreviewsEnabled
            ? event.preview
            : 'New message';
    _show(
      id:
          'message:${event.connectionId}:${event.createdAt.microsecondsSinceEpoch}',
      title: event.senderName,
      body: body,
      channel: _channelFor(
        AppNotificationKind.unknown,
        sound: sound,
        vibration: vibration,
        message: true,
      ),
      payload: {
        'route': 'chat',
        'connectionId': event.connectionId,
        'name': event.senderName,
        'skillName': event.skillName,
        'role': event.role,
        'avatarUrl': event.avatarUrl,
      },
      threadId: event.connectionId,
      quiet: quiet,
      sound: sound,
      vibration: vibration,
    );
  }

  Future<void> _show({
    required String id,
    required String title,
    required String body,
    required AndroidNotificationChannel channel,
    required Map<String, dynamic> payload,
    String? threadId,
    required bool quiet,
    required bool sound,
    required bool vibration,
  }) async {
    if (!isPermissionGranted) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.high,
        icon: 'ic_stat_palturo',
        styleInformation: BigTextStyleInformation(body),
        playSound: sound,
        enableVibration: vibration,
        silent: quiet || (!sound && !vibration),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentBadge: true,
        presentSound: sound,
        threadIdentifier: threadId,
      ),
      web: WebNotificationDetails(
        iconUrl: Uri.parse('icons/Icon-192.png'),
        isSilent: quiet || !sound,
      ),
    );
    try {
      await _plugin.show(
        id: _notificationId(id),
        title: title,
        body: body,
        notificationDetails: details,
        payload: jsonEncode(payload),
      );
    } catch (_) {
      // Best-effort: a failed system notification must not break the event.
    }
  }

  Future<void> _createChannels(
    AndroidFlutterLocalNotificationsPlugin android,
  ) async {
    for (final base in [_messagesChannel, _requestsChannel, _activityChannel]) {
      for (final sound in [true, false]) {
        for (final vibration in [true, false]) {
          if (sound && vibration) {
            await android.createNotificationChannel(base);
            continue;
          }
          final suffix =
              sound
                  ? '_sound'
                  : vibration
                  ? '_vibration'
                  : '_quiet';
          final label =
              sound
                  ? ' (sound only)'
                  : vibration
                  ? ' (vibration only)'
                  : ' (silent)';
          await android.createNotificationChannel(
            AndroidNotificationChannel(
              '${base.id}$suffix',
              '${base.name}$label',
              description: base.description,
              importance: base.importance,
              playSound: sound,
              enableVibration: vibration,
            ),
          );
        }
      }
    }
  }

  AndroidNotificationChannel _channelFor(
    AppNotificationKind kind, {
    required bool sound,
    required bool vibration,
    bool message = false,
  }) {
    final base =
        message
            ? _messagesChannel
            : switch (kind) {
              AppNotificationKind.connectionRequest ||
              AppNotificationKind.requestAccepted ||
              AppNotificationKind.requestDeclined => _requestsChannel,
              AppNotificationKind.feedbackReady ||
              AppNotificationKind.skillModeration ||
              AppNotificationKind.unknown => _activityChannel,
            };
    if (sound && vibration) return base;
    final suffix =
        sound
            ? '_sound'
            : vibration
            ? '_vibration'
            : '_quiet';
    final label =
        sound
            ? ' (sound only)'
            : vibration
            ? ' (vibration only)'
            : ' (silent)';
    return AndroidNotificationChannel(
      '${base.id}$suffix',
      '${base.name}$label',
      description: base.description,
      importance: base.importance,
      playSound: sound,
      enableVibration: vibration,
    );
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
  String channelIdFor(
    AppNotificationKind kind, {
    required bool sound,
    required bool vibration,
    bool message = false,
  }) {
    return _channelFor(
      kind,
      sound: sound,
      vibration: vibration,
      message: message,
    ).id;
  }

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
    WidgetsBinding.instance.removeObserver(this);
    _notificationSub?.cancel();
    _messageSub?.cancel();
    super.dispose();
  }
}
