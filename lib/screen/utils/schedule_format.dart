const List<String> _shortDays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String formatScheduleDays(Iterable<String> days) {
  final selected = <int>{};
  for (final raw in days) {
    final colonIdx = raw.indexOf(':');
    final day = (colonIdx == -1 ? raw : raw.substring(0, colonIdx)).trim();
    if (day.length < 3) continue;
    final index = _shortDays.indexWhere(
      (d) => d.toLowerCase() == day.substring(0, 3).toLowerCase(),
    );
    if (index != -1) selected.add(index);
  }

  if (selected.isEmpty) return '';
  if (selected.length == 7) return 'Everyday';

  const weekdayIndexes = {0, 1, 2, 3, 4};
  const weekendIndexes = {5, 6};

  final hasAllWeekdays = selected.containsAll(weekdayIndexes);
  final hasAllWeekend = selected.containsAll(weekendIndexes);

  final parts = <String>[];
  var weekdaysAdded = false;
  var weekendAdded = false;

  for (final i in selected.toList()..sort()) {
    if (hasAllWeekdays && weekdayIndexes.contains(i)) {
      if (!weekdaysAdded) {
        parts.add('Weekdays');
        weekdaysAdded = true;
      }
    } else if (hasAllWeekend && weekendIndexes.contains(i)) {
      if (!weekendAdded) {
        parts.add('Weekend');
        weekendAdded = true;
      }
    } else {
      parts.add(_shortDays[i]);
    }
  }

  return parts.join('/');
}

String formatSchedule(String schedule) {
  final formatted = formatScheduleDays(schedule.split('/'));
  return formatted.isEmpty ? schedule.trim() : formatted;
}