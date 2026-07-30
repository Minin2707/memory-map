import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  group('AuthSession', () {
    test('shouldCreateAuthSession', () {
      final user = createUser();
      final tokens = createTokens();

      final session = AuthSession(
        user: user,
        tokens: tokens,
      );

      expect(session.user, user);
      expect(session.tokens, tokens);
    });

    test('shouldExposeUserAndTokensThroughFields', () {
      final user = createUser();
      final tokens = createTokens();

      final session = AuthSession(
        user: user,
        tokens: tokens,
      );

      expect(session.user.id, 'user-id');
      expect(session.tokens.accessToken, 'signed-access-token');
      expect(session.tokens.refreshToken, 'raw-refresh-token');
    });

    test('shouldCompareSessionsByValue', () {
      final first = AuthSession(
        user: createUser(),
        tokens: createTokens(),
      );
      final second = AuthSession(
        user: createUser(),
        tokens: createTokens(),
      );
      final different = AuthSession(
        user: AuthUser(
          id: 'another-user-id',
          displayName: 'Ada Lovelace',
          avatarUrl: 'https://example.com/avatar.png',
        ),
        tokens: createTokens(),
      );

      expect(first, second);
      expect(first, isNot(different));
    });

    test('shouldProduceStableHashCode', () {
      final first = AuthSession(
        user: createUser(),
        tokens: createTokens(),
      );
      final second = AuthSession(
        user: createUser(),
        tokens: createTokens(),
      );

      expect(first.hashCode, second.hashCode);
    });

    test('shouldRedactSessionInToString', () {
      final session = AuthSession(
        user: createUser(),
        tokens: createTokens(),
      );

      expect(session.toString(), 'AuthSession[REDACTED]');
      expect(session.toString(), isNot(contains('signed-access-token')));
      expect(session.toString(), isNot(contains('raw-refresh-token')));
      expect(session.toString(), isNot(contains('user-id')));
      expect(session.toString(), isNot(contains('Ada Lovelace')));
      expect(
        session.toString(),
        isNot(contains('https://example.com/avatar.png')),
      );
    });
  });
}

AuthUser createUser() {
  return AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: 'https://example.com/avatar.png',
  );
}

AuthTokens createTokens() {
  return AuthTokens(
    accessToken: 'signed-access-token',
    refreshToken: 'raw-refresh-token',
  );
}
