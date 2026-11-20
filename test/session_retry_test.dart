import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/utils/session_retry.dart';

class _Unauthorized implements Exception {
  const _Unauthorized();
}

void main() {
  test('a healthy call never refreshes or expires', () async {
    var refreshes = 0;
    var expirations = 0;
    final result = await retryOnUnauthorized<int>(
      call: () async => 7,
      refresh: () async {
        refreshes++;
        return true;
      },
      expire: () async => expirations++,
      isUnauthorized: (error) => error is _Unauthorized,
    );

    expect(result, 7);
    expect(refreshes, 0);
    expect(expirations, 0);
  });

  test('one 401 refreshes once and retries the call', () async {
    var calls = 0;
    var refreshes = 0;
    var expirations = 0;
    final result = await retryOnUnauthorized<String>(
      call: () async {
        calls++;
        if (calls == 1) throw const _Unauthorized();
        return 'ok';
      },
      refresh: () async {
        refreshes++;
        return true;
      },
      expire: () async => expirations++,
      isUnauthorized: (error) => error is _Unauthorized,
    );

    expect(result, 'ok');
    expect(calls, 2);
    expect(refreshes, 1);
    expect(expirations, 0);
  });

  test('a failed refresh expires the session instead of retrying', () async {
    var calls = 0;
    var expirations = 0;
    await expectLater(
      retryOnUnauthorized<void>(
        call: () async {
          calls++;
          throw const _Unauthorized();
        },
        refresh: () async => false,
        expire: () async => expirations++,
        isUnauthorized: (error) => error is _Unauthorized,
      ),
      throwsA(isA<SessionExpiredException>()),
    );

    expect(calls, 1);
    expect(expirations, 1);
  });

  test('a throwing refresh is treated as a failed refresh', () async {
    var expirations = 0;
    await expectLater(
      retryOnUnauthorized<void>(
        call: () async => throw const _Unauthorized(),
        refresh: () async => throw Exception('offline'),
        expire: () async => expirations++,
        isUnauthorized: (error) => error is _Unauthorized,
      ),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(expirations, 1);
  });

  test('a second 401 after refresh expires the session', () async {
    var calls = 0;
    var expirations = 0;
    await expectLater(
      retryOnUnauthorized<void>(
        call: () async {
          calls++;
          throw const _Unauthorized();
        },
        refresh: () async => true,
        expire: () async => expirations++,
        isUnauthorized: (error) => error is _Unauthorized,
      ),
      throwsA(isA<SessionExpiredException>()),
    );

    expect(calls, 2);
    expect(expirations, 1);
  });

  test('a throwing expire still reports the expired session', () async {
    await expectLater(
      retryOnUnauthorized<void>(
        call: () async => throw const _Unauthorized(),
        refresh: () async => false,
        expire: () async => throw StateError('cleanup failed'),
        isUnauthorized: (error) => error is _Unauthorized,
      ),
      throwsA(isA<SessionExpiredException>()),
    );
  });

  test('a non-auth failure on the retry is rethrown, not expired', () async {
    var calls = 0;
    var expirations = 0;
    await expectLater(
      retryOnUnauthorized<void>(
        call: () async {
          calls++;
          if (calls == 1) throw const _Unauthorized();
          throw StateError('second call failed');
        },
        refresh: () async => true,
        expire: () async => expirations++,
        isUnauthorized: (error) => error is _Unauthorized,
      ),
      throwsA(isA<StateError>()),
    );

    expect(calls, 2);
    expect(expirations, 0);
  });

  test('non-auth failures are rethrown untouched', () async {
    var refreshes = 0;
    var expirations = 0;
    await expectLater(
      retryOnUnauthorized<void>(
        call: () async => throw StateError('boom'),
        refresh: () async {
          refreshes++;
          return true;
        },
        expire: () async => expirations++,
        isUnauthorized: (error) => error is _Unauthorized,
      ),
      throwsA(isA<StateError>()),
    );

    expect(refreshes, 0);
    expect(expirations, 0);
  });
}
