import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/models/account_warning.dart';
import 'package:palturo/models/app_notification.dart';
import 'package:palturo/screen/activity_presentation.dart';

void main() {
  test('account warning parses server fields defensively', () {
    final warning = AccountWarning.fromRow({
      'id': 'w1',
      'category': 'harassment',
      'message': 'Please review the community guidelines.',
      'created_at': '2026-11-20T00:00:00Z',
      'visible_until': '2026-12-20T00:00:00Z',
      'acknowledged_at': null,
    });

    expect(warning.id, 'w1');
    expect(warning.categoryLabel, 'Harassment');
    expect(warning.message, contains('community guidelines'));
    expect(warning.isAcknowledged, isFalse);
    expect(warning.visibleUntil.isAfter(warning.createdAt), isTrue);
  });

  test('expired account warnings report not visible', () {
    final warning = AccountWarning.fromRow({
      'id': 'w2',
      'category': 'spam',
      'message': 'Spam',
      'created_at': '2026-01-01T00:00:00Z',
      'visible_until': '2026-01-08T00:00:00Z',
    });
    expect(warning.isVisible, isFalse);
  });

  test('account warning notification presents the message and routes to standing',
      () {
    final view = presentActivity({
      'kind': 'account_warning',
      'payload': {
        'message': 'Your profile was reported for spam.',
        'category': 'spam',
      },
    });

    expect(view.title, 'Account warning');
    expect(view.body, contains('reported for spam'));
    expect(view.actionLabel, 'Review');
    expect(view.destination, ActivityDestination.accountStanding);
  });

  test('account warning without a message uses safe copy', () {
    final view = presentActivity({
      'kind': 'account_warning',
      'payload': {'category': 'harassment'},
    });

    expect(view.title, 'Account warning');
    expect(view.body, contains('Account standing'));
    expect(view.destination, ActivityDestination.accountStanding);
  });

  test('account warning is a known notification kind', () {
    expect(
      AppNotificationKind.fromWire('account_warning'),
      AppNotificationKind.accountWarning,
    );
    expect(AppNotificationKind.accountWarning.isAccountNotice, isTrue);
  });
}
