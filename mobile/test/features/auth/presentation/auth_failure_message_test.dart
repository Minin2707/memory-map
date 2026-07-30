import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/presentation/auth_failure_message.dart';

void main() {
  group('authFailureMessage', () {
    test('shouldReturnSafeMessagesForKnownFailures', () {
      expect(authFailureMessage(const AuthCancelled()), 'Sign-in was cancelled.');
      expect(
        authFailureMessage(const GoogleAuthenticationUnavailable()),
        'Google sign-in is unavailable on this device.',
      );
      expect(
        authFailureMessage(const GoogleAuthenticationFailed()),
        'Could not sign in with Google. Please try again.',
      );
      expect(
        authFailureMessage(const BackendUnauthorized()),
        'Authentication was rejected. Please try again.',
      );
      expect(
        authFailureMessage(const RequestValidationFailed()),
        'The sign-in request was invalid. Please try again.',
      );
      expect(
        authFailureMessage(const NetworkUnavailable()),
        'No network connection. Check your connection and try again.',
      );
      expect(
        authFailureMessage(const RequestTimedOut()),
        'The request timed out. Please try again.',
      );
      expect(
        authFailureMessage(const ServerFailure()),
        'The server is temporarily unavailable. Please try again.',
      );
      expect(
        authFailureMessage(const SecureStorageFailure()),
        'Could not securely save your session. Please try again.',
      );
      expect(
        authFailureMessage(const CorruptSession()),
        'Local session data was invalid. Please try again.',
      );
      expect(
        authFailureMessage(const UnknownAuthFailure()),
        'Something went wrong. Please try again.',
      );
    });

    test('shouldNotExposeFailureTypeNames', () {
      final messages = [
        authFailureMessage(const AuthCancelled()),
        authFailureMessage(const GoogleAuthenticationUnavailable()),
        authFailureMessage(const GoogleAuthenticationFailed()),
        authFailureMessage(const BackendUnauthorized()),
        authFailureMessage(const RequestValidationFailed()),
        authFailureMessage(const NetworkUnavailable()),
        authFailureMessage(const RequestTimedOut()),
        authFailureMessage(const ServerFailure()),
        authFailureMessage(const SecureStorageFailure()),
        authFailureMessage(const CorruptSession()),
        authFailureMessage(const UnknownAuthFailure()),
      ];

      for (final message in messages) {
        expect(message, isNotEmpty);
        expect(message, isNot(contains('AuthFailure')));
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('Dio')));
        expect(message, isNot(contains('client-id')));
        expect(message, isNot(contains('access-token')));
        expect(message, isNot(contains('refresh-token')));
        expect(message, isNot(contains('StackTrace')));
      }
    });
  });
}
