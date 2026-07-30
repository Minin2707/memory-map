import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/domain/google_identity_exception.dart';

void main() {
  group('GoogleIdentityException', () {
    test('shouldCreateCancelledException', () {
      expect(
        const GoogleIdentityCancelledException(),
        isA<GoogleIdentityException>(),
      );
    });

    test('shouldCreateUnavailableException', () {
      expect(
        const GoogleIdentityUnavailableException(),
        isA<GoogleIdentityException>(),
      );
    });

    test('shouldCreateAuthenticationException', () {
      expect(
        const GoogleIdentityAuthenticationException(),
        isA<GoogleIdentityException>(),
      );
    });

    test('shouldCompareSameExceptionTypesSafely', () {
      expect(
        const GoogleIdentityCancelledException(),
        const GoogleIdentityCancelledException(),
      );
      expect(
        const GoogleIdentityUnavailableException(),
        const GoogleIdentityUnavailableException(),
      );
      expect(
        const GoogleIdentityAuthenticationException(),
        const GoogleIdentityAuthenticationException(),
      );
      expect(
        const GoogleIdentityCancelledException(),
        isNot(const GoogleIdentityUnavailableException()),
      );
    });

    test('shouldExposeOnlySafeExceptionType', () {
      expect(
        const GoogleIdentityCancelledException().toString(),
        'GoogleIdentityCancelledException',
      );
      expect(
        const GoogleIdentityUnavailableException().toString(),
        'GoogleIdentityUnavailableException',
      );
      expect(
        const GoogleIdentityAuthenticationException().toString(),
        'GoogleIdentityAuthenticationException',
      );
    });

    test('shouldNotExposeClientIdOrTokenInToString', () {
      const sensitiveValues = <String>[
        'web-client-id.apps.googleusercontent.com',
        'ios-client-id.apps.googleusercontent.com',
        'raw-google-id-token',
      ];

      const exceptions = <GoogleIdentityException>[
        GoogleIdentityCancelledException(),
        GoogleIdentityUnavailableException(),
        GoogleIdentityAuthenticationException(),
      ];

      for (final exception in exceptions) {
        for (final value in sensitiveValues) {
          expect(exception.toString(), isNot(contains(value)));
        }
      }
    });
  });
}
