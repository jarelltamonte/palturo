import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/request_page.dart';

void main() {
  // Friday, 23 October 2026, 12:00 local.
  final now = DateTime(2026, 10, 23, 12);
  final startOfWeek = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));

  test('all accepts every date', () {
    expect(
      matchesRequestDate(DateTime(1999), DateFilter.all, now: now),
      isTrue,
    );
    expect(
      matchesRequestDate(DateTime(2099), DateFilter.all, now: now),
      isTrue,
    );
  });

  test('today is calendar-day based', () {
    expect(
      matchesRequestDate(DateTime(2026, 10, 23), DateFilter.today, now: now),
      isTrue,
    );
    expect(
      matchesRequestDate(DateTime(2026, 10, 22), DateFilter.today, now: now),
      isFalse,
    );
    expect(
      matchesRequestDate(DateTime(2026, 10, 24), DateFilter.today, now: now),
      isFalse,
    );
  });

  test('this week starts Monday and excludes the future', () {
    expect(
      matchesRequestDate(startOfWeek, DateFilter.thisWeek, now: now),
      isTrue,
    );
    expect(
      matchesRequestDate(
        startOfWeek.subtract(const Duration(seconds: 1)),
        DateFilter.thisWeek,
        now: now,
      ),
      isFalse,
    );
    expect(
      matchesRequestDate(
        now.add(const Duration(days: 1)),
        DateFilter.thisWeek,
        now: now,
      ),
      isFalse,
    );
  });

  test('this month and year exclude dates after now', () {
    expect(
      matchesRequestDate(DateTime(2026, 10, 1), DateFilter.thisMonth, now: now),
      isTrue,
    );
    expect(
      matchesRequestDate(DateTime(2026, 9, 30), DateFilter.thisMonth, now: now),
      isFalse,
    );
    expect(
      matchesRequestDate(DateTime(2026, 11, 1), DateFilter.thisMonth, now: now),
      isFalse,
    );
    expect(
      matchesRequestDate(
        DateTime(2026, 10, 30),
        DateFilter.thisMonth,
        now: now,
      ),
      isFalse,
    );
    expect(
      matchesRequestDate(DateTime(2026, 1, 1), DateFilter.thisYear, now: now),
      isTrue,
    );
    expect(
      matchesRequestDate(DateTime(2027, 1, 1), DateFilter.thisYear, now: now),
      isFalse,
    );
    expect(
      matchesRequestDate(DateTime(2026, 12, 31), DateFilter.thisYear, now: now),
      isFalse,
    );
  });
}
