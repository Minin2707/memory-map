import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';

void main() {
  group('AuthTokens', () {
    test('shouldCreateAuthTokens', () {
      final tokens = AuthTokens(
        accessToken: 'signed-access-token',
        refreshToken: 'raw-refresh-token',
      );

      expect(tokens.accessToken, 'signed-access-token');
      expect(tokens.refreshToken, 'raw-refresh-token');
    });

    test('shouldRejectEmptyAccessToken', () {
      expect(
        () => AuthTokens(
          accessToken: '',
          refreshToken: 'raw-refresh-token',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'accessToken must not be blank',
          ),
        ),
      );
    });

    test('shouldRejectWhitespaceAccessToken', () {
      expect(
        () => AuthTokens(
          accessToken: '   ',
          refreshToken: 'raw-refresh-token',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'accessToken must not be blank',
          ),
        ),
      );
    });

    test('shouldRejectEmptyRefreshToken', () {
      expect(
        () => AuthTokens(
          accessToken: 'signed-access-token',
          refreshToken: '',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'refreshToken must not be blank',
          ),
        ),
      );
    });

    test('shouldRejectWhitespaceRefreshToken', () {
      expect(
        () => AuthTokens(
          accessToken: 'signed-access-token',
          refreshToken: '   ',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'refreshToken must not be blank',
          ),
        ),
      );
    });

    test('shouldCompareAuthTokensByValue', () {
      final first = AuthTokens(
        accessToken: 'signed-access-token',
        refreshToken: 'raw-refresh-token',
      );
      final second = AuthTokens(
        accessToken: 'signed-access-token',
        refreshToken: 'raw-refresh-token',
      );
      final different = AuthTokens(
        accessToken: 'another-signed-access-token',
        refreshToken: 'raw-refresh-token',
      );

      expect(first, second);
      expect(first, isNot(different));
    });

    test('shouldProduceStableHashCode', () {
      final first = AuthTokens(
        accessToken: 'signed-access-token',
        refreshToken: 'raw-refresh-token',
      );
      final second = AuthTokens(
        accessToken: 'signed-access-token',
        refreshToken: 'raw-refresh-token',
      );

      expect(first.hashCode, second.hashCode);
    });

    test('shouldRedactTokensInToString', () {
      const accessToken = 'signed-access-token';
      const refreshToken = 'raw-refresh-token';

      final tokens = AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      expect(tokens.toString(), 'AuthTokens[REDACTED]');
      expect(tokens.toString(), isNot(contains(accessToken)));
      expect(tokens.toString(), isNot(contains(refreshToken)));
    });
  });
}
