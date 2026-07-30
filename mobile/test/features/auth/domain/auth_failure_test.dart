import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';

void main() {
  group('AuthFailure', () {
    test('shouldCreateAllAuthFailureVariants', () {
      const failures = <AuthFailure>[
        AuthCancelled(),
        GoogleAuthenticationUnavailable(),
        GoogleAuthenticationFailed(),
        BackendUnauthorized(),
        RequestValidationFailed(),
        NetworkUnavailable(),
        RequestTimedOut(),
        ServerFailure(),
        SecureStorageFailure(),
        CorruptSession(),
        UnknownAuthFailure(),
      ];

      expect(failures, hasLength(11));
    });

    test('shouldCompareSameFailureTypesAsEqual', () {
      expect(const AuthCancelled(), const AuthCancelled());
      expect(const NetworkUnavailable(), const NetworkUnavailable());
      expect(const UnknownAuthFailure(), const UnknownAuthFailure());
    });

    test('shouldCompareDifferentFailureTypesAsNotEqual', () {
      expect(const AuthCancelled(), isNot(const NetworkUnavailable()));
      expect(const ServerFailure(), isNot(const RequestTimedOut()));
      expect(const BackendUnauthorized(), isNot(const UnknownAuthFailure()));
    });

    test('shouldProduceStableHashCodeForSameFailureType', () {
      expect(
        const AuthCancelled().hashCode,
        const AuthCancelled().hashCode,
      );
      expect(
        const NetworkUnavailable().hashCode,
        const NetworkUnavailable().hashCode,
      );
      expect(
        const UnknownAuthFailure().hashCode,
        const UnknownAuthFailure().hashCode,
      );
    });

    test('shouldExposeOnlySafeFailureTypeInToString', () {
      const failure = NetworkUnavailable();

      expect(failure.toString(), 'NetworkUnavailable');
      expect(failure.toString(), isNot(contains('token')));
      expect(failure.toString(), isNot(contains('exception')));
      expect(failure.toString(), isNot(contains('Dio')));
      expect(failure.toString(), isNot(contains('HTTP response')));
      expect(failure.toString(), isNot(contains('Google ID Token')));
      expect(failure.toString(), isNot(contains('stack trace')));
    });
  });
}
