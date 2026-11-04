import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/services/profile_service.dart';

void main() {
  test('name status parses quota and cooldown', () {
    final status = NameChangeStatus.fromMap({
      'changes_used': 1,
      'changes_remaining': 1,
      'can_change': false,
      'next_change_at': '2027-01-03T00:00:00Z',
    });

    expect(status.changesUsed, 1);
    expect(status.changesRemaining, 1);
    expect(status.canChange, isFalse);
    expect(status.nextChangeAt, DateTime.utc(2027, 1, 3));
  });

  test('name status allows the first change', () {
    final status = NameChangeStatus.fromMap({
      'changes_used': 0,
      'changes_remaining': 2,
      'can_change': true,
      'next_change_at': null,
    });

    expect(status.changesRemaining, 2);
    expect(status.canChange, isTrue);
    expect(status.nextChangeAt, isNull);
  });
}
