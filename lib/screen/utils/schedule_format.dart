const List<String> kCanonicalDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _shortDays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Extracts and canonicalizes day selections from any source (List, Map, String, null).
/// Expands composite labels like "Weekdays", "Weekends", "Everyday" into individual days.
/// Returns a list of canonical full day names ('Monday'..'Sunday') sorted in chronological order.
List<String> parseAvailableDays(dynamic input) {
  if (input == null) return const [];

  final selected = <int>{};

  void processSegment(String raw) {
    var segment = raw.trim();
    if (segment.isEmpty) return;

    final colonIdx = segment.indexOf(':');
    if (colonIdx != -1) {
      segment = segment.substring(0, colonIdx).trim();
    }
    if (segment.isEmpty) return;

    final lower = segment.toLowerCase();
    if (lower == 'no schedule set' ||
        lower == 'no schedules set' ||
        lower == 'not set') {
      return;
    }

    if (lower == 'everyday' || lower == 'every day' || lower == 'all days') {
      selected.addAll([0, 1, 2, 3, 4, 5, 6]);
      return;
    }

    if (lower == 'weekdays' || lower == 'weekday') {
      selected.addAll([0, 1, 2, 3, 4]);
      return;
    }

    if (lower == 'weekends' || lower == 'weekend') {
      selected.addAll([5, 6]);
      return;
    }

    if (segment.contains('/') || segment.contains(',')) {
      final delimiter = segment.contains('/') ? '/' : ',';
      for (final sub in segment.split(delimiter)) {
        processSegment(sub);
      }
      return;
    }

    if (segment.length >= 3) {
      final prefix = segment.substring(0, 3).toLowerCase();
      final index = _shortDays.indexWhere((d) => d.toLowerCase() == prefix);
      if (index != -1) {
        selected.add(index);
      }
    }
  }

  if (input is Iterable) {
    for (final item in input) {
      if (item != null) processSegment(item.toString());
    }
  } else if (input is Map) {
    for (final key in input.keys) {
      if (key != null) processSegment(key.toString());
    }
  } else if (input is String) {
    processSegment(input);
  }

  final sortedList = selected.toList()..sort();
  return sortedList.map((i) => kCanonicalDays[i]).toList();
}

String formatScheduleDays(Iterable<String> days) {
  final canonicalDays = parseAvailableDays(days);
  final selected = <int>{};
  for (final day in canonicalDays) {
    final idx = kCanonicalDays.indexOf(day);
    if (idx != -1) selected.add(idx);
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
        parts.add('Weekends');
        weekendAdded = true;
      }
    } else {
      parts.add(_shortDays[i]);
    }
  }

  return parts.join('/');
}

String formatSchedule(dynamic schedule) {
  if (schedule == null) return '';
  final days = parseAvailableDays(schedule);
  return formatScheduleDays(days);
}
