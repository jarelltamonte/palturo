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
      lower.contains('internet connection') ||
      lower.contains('check your connection') ||
      lower.contains('failed to fetch') ||
      lower.contains('xmlhttprequest')) {
    return 'Please check your connection and try again.';
  }

  // Auth failures are actionable: the user needs a fresh session, not a retry
  // loop. This must run before the technical-noise filter because Supabase
  // function errors arrive as `minified:…(status: 401, … Unauthorized …)`.
  final has401 = RegExp(r'(^|\D)401(\D|$)').hasMatch(raw);
  if (has401 ||
      lower.contains('session_not_found') ||
      lower.contains('session expired') ||
      lower.contains('session has expired') ||
      lower.contains('session missing') ||
      lower.contains('authsessionmissing') ||
      lower.contains('invalid token') ||
      lower.contains('jwt') ||
      lower.contains('unauthorized') ||
      lower.contains('not authenticated') ||
      lower.contains('invalid claim')) {
    return 'Your session has expired. Please sign in again.';
  }

  // Technical driver/SQL text must never reach a snackbar, even when it
  // contains words like "password" or "character".
  if (lower.contains('minified:') ||
      lower.contains('reasonphrase') ||
      lower.contains('functionexception') ||
      lower.contains('postgrest') ||
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

  if (lower.contains('too many') ||
      lower.contains('rate limit') ||
      lower.contains('for security purposes') ||
      lower.contains('can only request this') ||
      lower.contains('429')) {
    if (raw.isEmpty) return 'Too many requests. Please try again later.';
    // Wrapped SDK exceptions would leak the class name and fields; replace
    // them with a readable wait, keeping plain user-facing copy untouched.
    if (lower.contains('authapiexception') || lower.contains('statuscode:')) {
      final wait = RegExp(
        r'after\s+(\d+)\s+seconds?',
      ).firstMatch(lower)?.group(1);
      return wait == null
          ? 'Too many requests. Please wait a moment and try again.'
          : 'Too many attempts. Please try again in $wait seconds.';
    }
    return raw;
  }

  if (lower.contains('invalid') ||
      lower.contains('required') ||
      lower.contains('validation') ||
      lower.contains('permission') ||
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
      lower.contains('name') ||
      lower.contains('delete your account') ||
      lower.contains('account deletion') ||
      lower.contains('unable to delete')) {
    return raw.isEmpty ? fallback : raw;
  }
  return fallback;
}
