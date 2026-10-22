class ChatTimeFormatter {
  static const List<String> _shortWeekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats a 12-hour time string (e.g. "9:41 PM").
  static String formatTimeOnly(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Formats the chat list preview timestamp:
  /// - Today -> "9:41 PM"
  /// - Yesterday -> "Yesterday"
  /// - Within last 7 days -> Day of week (e.g. "Mon")
  /// - Older -> "Oct 12" (or "Oct 12, 2025" if different year)
  static String formatChatListTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final local = dateTime.toLocal();
    final now = DateTime.now();

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(local.year, local.month, local.day);
    final diffDays = todayMidnight.difference(targetMidnight).inDays;

    if (diffDays == 0) {
      return formatTimeOnly(local);
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else if (diffDays > 1 && diffDays < 7) {
      return _shortWeekdays[local.weekday - 1];
    } else {
      if (local.year == now.year) {
        return '${_shortMonths[local.month - 1]} ${local.day}';
      } else {
        return '${_shortMonths[local.month - 1]} ${local.day}, ${local.year}';
      }
    }
  }

  /// Messenger-style centered session header (e.g. "Today 9:41 PM", "Yesterday 3:15 PM", "Mon 10:20 AM", "Oct 12, 9:41 PM")
  static String formatMessengerHeader(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(local.year, local.month, local.day);
    final diffDays = todayMidnight.difference(targetMidnight).inDays;
    final timeStr = formatTimeOnly(local);

    if (diffDays == 0) {
      return timeStr;
    } else if (diffDays == 1) {
      return 'Yesterday $timeStr';
    } else if (diffDays > 1 && diffDays < 7) {
      return '${_shortWeekdays[local.weekday - 1]} $timeStr';
    } else {
      if (local.year == now.year) {
        return '${_shortMonths[local.month - 1]} ${local.day}, $timeStr';
      } else {
        return '${_shortMonths[local.month - 1]} ${local.day}, ${local.year}, $timeStr';
      }
    }
  }

  /// Determines whether a new Messenger-style header should be displayed between two messages.
  /// Shows header if:
  /// - previousMessageTime is null (first message), or
  /// - difference between messages is greater than 20 minutes, or
  /// - messages were sent on different calendar days.
  static bool shouldShowMessengerHeader(DateTime? previous, DateTime current) {
    if (previous == null) return true;
    final prevLocal = previous.toLocal();
    final currLocal = current.toLocal();

    // Check calendar day difference
    if (prevLocal.year != currLocal.year ||
        prevLocal.month != currLocal.month ||
        prevLocal.day != currLocal.day) {
      return true;
    }

    // Check elapsed time > 20 minutes
    final diff = currLocal.difference(prevLocal).abs();
    return diff.inMinutes >= 20;
  }
}
