import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';

void main() {
  group('AuthApplicationException', () {
    test('shouldExposeAuthFailure', () {
      const exception = AuthApplicationException(AuthCancelled());

      expect(exception.failure, const AuthCancelled());
    });

    test('shouldUseSafeToString', () {
      const exception = AuthApplicationException(AuthCancelled());

      expect(exception.toString(), 'AuthApplicationException');
    });

    test('shouldNotExposeTokenOrInfrastructureDetails', () {
      const sensitiveValues = <String>[
        'raw-google-id-token',
        'signed-access-token',
        'raw-refresh-token',
        'google-client-id',
        'DioException',
        'GoogleSignInException',
        'AuthSessionStorageException',
      ];
      const exception = AuthApplicationException(AuthCancelled());

      for (final value in sensitiveValues) {
        expect(exception.toString(), isNot(contains(value)));
      }
    });
  });
}
