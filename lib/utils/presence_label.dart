/// Human-readable presence for chat rows and headers.
///
/// Returns null when the peer has presence disabled or the timestamp is too
/// old to be useful; callers then keep their normal secondary text.
String? presenceLabel(
  DateTime? lastSeen, {
  required bool enabled,
  DateTime? now,
}) {
  if (!enabled || lastSeen == null) return null;
  final current = now ?? DateTime.now();
  if (presenceIsOnline(lastSeen, enabled: enabled, now: current)) {
    return 'Online';
  }
  final diff = current.difference(lastSeen);
  if (diff.inHours < 1) {
    final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return 'Active ${minutes}m ago';
  }
  if (diff.inDays < 1) return 'Active ${diff.inHours}h ago';
  if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
  return null;
}

bool presenceIsOnline(
  DateTime? lastSeen, {
  required bool enabled,
  DateTime? now,
}) {
  if (!enabled || lastSeen == null) return false;
  final current = now ?? DateTime.now();
  return current.difference(lastSeen).inMinutes < 2;
}
