import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/app_badge_service.dart';
import 'package:palturo/services/connectivity_service.dart';

void main() {
  test('badge count combines activity and message unread', () {
    expect(
      combinedBadgeCount(activityUnread: 2, messageUnread: 3, enabled: true),
      5,
    );
    expect(
      combinedBadgeCount(activityUnread: 2, messageUnread: 3, enabled: false),
      0,
    );
    expect(
      combinedBadgeCount(activityUnread: -1, messageUnread: 0, enabled: true),
      0,
    );
  });

  test('connectivity notifies only on change', () {
    final service = ConnectivityService.instance;
    var notifications = 0;
    void listener() => notifications++;
    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    service.debugSetOnline(true);
    expect(notifications, 0);

    service.debugSetOnline(false);
    expect(service.online, isFalse);
    expect(notifications, 1);

    service.debugSetOnline(false);
    expect(notifications, 1);

    service.debugSetOnline(true);
    expect(service.online, isTrue);
    expect(notifications, 2);
  });
}
