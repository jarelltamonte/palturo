/// Thrown when a call proves the stored session is no longer valid.
///
/// [friendlyError] turns this into "Your session has expired. Please sign in
/// again."; the auth listener then routes the user back to login.
class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'Your session has expired. Please sign in again.';
}

/// Runs [call], refreshing the session once when [isUnauthorized] matches.
///
/// A 401 cannot be fixed by repeating the same request: the token is expired
/// or revoked. Refresh first; if that fails, expire the session so the caller
/// stops offering a Retry that can never succeed. Non-auth errors are rethrown
/// untouched so existing handling keeps working.
Future<T> retryOnUnauthorized<T>({
  required Future<T> Function() call,
  required Future<bool> Function() refresh,
  required Future<void> Function() expire,
  required bool Function(Object error) isUnauthorized,
}) async {
  Future<Never> expireSession() async {
    try {
      await expire();
    } catch (_) {
      // Clearing the session is best-effort; the caller still needs the
      // session-expired signal rather than the cleanup error.
    }
    throw const SessionExpiredException();
  }

  try {
    return await call();
  } catch (error) {
    if (!isUnauthorized(error)) rethrow;
    var refreshed = false;
    try {
      refreshed = await refresh();
    } catch (_) {
      refreshed = false;
    }
    if (!refreshed) await expireSession();
  }

  try {
    return await call();
  } catch (error) {
    if (isUnauthorized(error)) await expireSession();
    rethrow;
  }
}
