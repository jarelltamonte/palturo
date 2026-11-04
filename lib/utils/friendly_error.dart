String friendlyError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final raw =
      error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  final lower = raw.toLowerCase();
  // Technical driver/SQL text must never reach a snackbar, even when it
  // contains words like "password" or "character".
  if (lower.contains('postgrest') ||
      lower.contains('sqlexception') ||
      lower.contains('varying(') ||
      lower.contains('password authentication') ||
      lower.contains('permission denied for table') ||
      lower.contains('relation "') ||
      lower.contains('column "') ||
      lower.contains('invalid input syntax') ||
      lower.contains('stack trace') ||
      lower.contains('user "')) {
    return fallback;
  }
  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('timeout') ||
      lower.contains('failed host') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('internet connection') ||
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
      lower.contains('unauthorized') ||
      lower.contains('password') ||
      lower.contains('character') ||
      lower.contains('letter') ||
      lower.contains('uppercase') ||
      lower.contains('lowercase') ||
      lower.contains('special') ||
      lower.contains('number') ||
      lower.contains('digit') ||
      lower.contains('same as') ||
      lower.contains('does not meet') ||
      lower.contains('delete your account') ||
      lower.contains('account deletion') ||
      lower.contains('unable to delete')) {
    return raw.isEmpty ? fallback : raw;
  }
  return fallback;
}
