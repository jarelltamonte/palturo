import 'dart:async';

import 'package:flutter/material.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/screen/notifications_page.dart';
import 'package:palturo/screen/profile_page.dart';
import 'package:palturo/screen/request_page.dart';
import 'package:palturo/services/app_navigator.dart';
import 'package:palturo/services/sound_service.dart';
import 'package:palturo/utils/media_url.dart';

/// Routes opened from notifications, banners, and deep links.
///
/// Every method is safe to call before the first frame: if the navigator is
/// not ready, the route is queued for the next frame.
class AppRouter {
  const AppRouter._();

  static NavigatorState? get _navigator => navigatorKey.currentState;

  static Future<void> _push(WidgetBuilder builder) async {
    unawaited(SoundService.instance.stop());
    final navigator = _navigator;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ready = _navigator;
        if (ready != null) {
          ready.push(MaterialPageRoute(builder: builder));
        }
      });
      return;
    }
    await navigator.push(MaterialPageRoute(builder: builder));
  }

  static Future<void> openActivity() => _push((_) => const NotificationsPage());

  static Future<void> openRequests({RequestView view = RequestView.incoming}) =>
      _push((_) => RequestPage(initialView: view));

  static Future<void> openChat({
    required String connectionId,
    required String name,
    String? skillName,
    PersonRole? role,
    Person? person,
    String? avatarUrl,
  }) {
    final avatar = MediaUrl.image(avatarUrl);
    return _push(
      (_) => ChatRoom(
        connectionId: connectionId,
        name: name,
        skillName: skillName,
        role: role,
        person: person,
        avatarImage: avatar,
      ),
    );
  }

  static Future<void> openProfile() => _push((_) => const ProfilePage());
}
