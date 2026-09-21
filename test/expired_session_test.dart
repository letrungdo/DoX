import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What PostgREST answers with once the access token has gone stale. It comes
/// back two ways depending on how far the request got: as the code itself,
/// and as a 401 whose message carries the code inside it.
final _expiredByCode = PostgrestException(
  message: 'JWT expired',
  code: 'PGRST303',
  details: 'Unauthorized',
);
final _expiredByMessage = PostgrestException(
  message:
      '{"code":"PGRST303","details":null,"hint":null,'
      '"message":"JWT expired"}',
  code: '401',
  details: 'Unauthorized',
);

void main() {
  group('Telling an expired session from a failed request', () {
    test('both shapes of the expired token are recognised', () {
      expect(isExpiredSessionError(_expiredByCode), isTrue);
      expect(isExpiredSessionError(_expiredByMessage), isTrue);
    });

    test('an ordinary database error is not', () {
      // Retrying this would only fail again, and signing the user out over it
      // would be the worst possible answer to a typo in a query.
      expect(
        isExpiredSessionError(
          PostgrestException(message: 'column does not exist', code: '42703'),
        ),
        isFalse,
      );
      expect(isExpiredSessionError(Exception('no internet')), isFalse);
    });
  });

  group('Requests behind the guard', () {
    test('a request that works is not retried', () async {
      var calls = 0;
      final result = await Result.guardFuture(() async {
        calls++;
        return 'ok';
      });

      expect(result.data, 'ok');
      expect(calls, 1);
    });

    test('an ordinary failure is reported, not retried', () async {
      var calls = 0;
      final result = await Result.guardFuture<String>(() async {
        calls++;
        throw PostgrestException(message: 'nope', code: '42703');
      });

      expect(result.isError, isTrue);
      expect(calls, 1);
    });
  });
}
