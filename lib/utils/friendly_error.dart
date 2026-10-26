String friendlyError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final raw =
      error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  final lower = raw.toLowerCase();
  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('timeout') ||
      lower.contains('failed host') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('check your connection')) {
    return 'Please check your connection and try again.';
  }
  if (lower.contains('too many') ||
      lower.contains('rate limit') ||
      lower.contains('429')) {
    return raw.isEmpty ? 'Too many requests. Please try again later.' : raw;
  }
  if (lower.contains('invalid') ||
      lower.contains('required') ||
      lower.contains('validation') ||
      lower.contains('not authenticated') ||
      lower.contains('permission') ||
      lower.contains('unauthorized')) {
    return raw.isEmpty ? fallback : raw;
  }
  return fallback;
}
