import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  group('AuthState', () {
    test('shouldCreateUnauthenticatedState', () {
      expect(const AuthUnauthenticated(), isA<AuthState>());
    });

    test('shouldCreateAuthenticatingState', () {
      expect(const AuthAuthenticating(), isA<AuthState>());
    });

    test('shouldCreateAuthenticatedState', () {
      final state = AuthAuthenticated(session);

      expect(state.session, session);
    });

    test('shouldCreateLoggingOutState', () {
      final state = AuthLoggingOut(session);

      expect(state.session, session);
    });

    test('shouldCreateLogoutFailureState', () {
      const failure = SecureStorageFailure();
      final state = AuthLogoutFailure(
        session: session,
        failure: failure,
      );

      expect(state.session, session);
      expect(state.failure, failure);
    });

    test('shouldCreateRestoreFailureState', () {
      const state = AuthRestoreFailure(NetworkUnavailable());

      expect(state.failure, const NetworkUnavailable());
    });

    test('shouldCreateLoginFailureState', () {
      const state = AuthLoginFailure(ServerFailure());

      expect(state.failure, const ServerFailure());
    });

    test('shouldCompareStatesByValue', () {
      expect(const AuthUnauthenticated(), const AuthUnauthenticated());
      expect(const AuthAuthenticating(), const AuthAuthenticating());
      expect(AuthAuthenticated(session), AuthAuthenticated(session));
      expect(AuthLoggingOut(session), AuthLoggingOut(session));
      expect(
        AuthLogoutFailure(
          session: session,
          failure: const SecureStorageFailure(),
        ),
        AuthLogoutFailure(
          session: session,
          failure: const SecureStorageFailure(),
        ),
      );
      expect(
        const AuthRestoreFailure(NetworkUnavailable()),
        const AuthRestoreFailure(NetworkUnavailable()),
      );
      expect(
        const AuthLoginFailure(ServerFailure()),
        const AuthLoginFailure(ServerFailure()),
      );
      expect(
        const AuthUnauthenticated(),
        isNot(const AuthAuthenticating()),
      );
    });

    test('shouldProduceStableHashCode', () {
      expect(
        const AuthUnauthenticated().hashCode,
        const AuthUnauthenticated().hashCode,
      );
      expect(
        AuthAuthenticated(session).hashCode,
        AuthAuthenticated(session).hashCode,
      );
      expect(
        AuthLoggingOut(session).hashCode,
        AuthLoggingOut(session).hashCode,
      );
      expect(
        AuthLogoutFailure(
          session: session,
          failure: const SecureStorageFailure(),
        ).hashCode,
        AuthLogoutFailure(
          session: session,
          failure: const SecureStorageFailure(),
        ).hashCode,
      );
      expect(
        const AuthLoginFailure(ServerFailure()).hashCode,
        const AuthLoginFailure(ServerFailure()).hashCode,
      );
    });

    test('shouldRedactAuthenticatedState', () {
      final state = AuthAuthenticated(session);

      expect(state.toString(), 'AuthAuthenticated[REDACTED]');
      expect(state.toString(), isNot(contains('user-id')));
      expect(state.toString(), isNot(contains('Ada Lovelace')));
      expect(
        state.toString(),
        isNot(contains('https://example.com/avatar.png')),
      );
      expect(state.toString(), isNot(contains('signed-access-token')));
      expect(state.toString(), isNot(contains('raw-refresh-token')));
    });

    test('shouldRedactLoggingOutState', () {
      final state = AuthLoggingOut(session);

      expect(state.toString(), 'AuthLoggingOut[REDACTED]');
      expectLogoutStateToBeRedacted(state);
    });

    test('shouldRedactLogoutFailureState', () {
      final state = AuthLogoutFailure(
        session: session,
        failure: const SecureStorageFailure(),
      );

      expect(state.toString(), 'AuthLogoutFailure[REDACTED]');
      expectLogoutStateToBeRedacted(state);
    });

    test('shouldUseSafeFailureStateToString', () {
      const restoreFailure = AuthRestoreFailure(NetworkUnavailable());
      const loginFailure = AuthLoginFailure(ServerFailure());

      expect(restoreFailure.toString(), 'AuthRestoreFailure');
      expect(loginFailure.toString(), 'AuthLoginFailure');
      expect(restoreFailure.toString(), isNot(contains('DioException')));
      expect(loginFailure.toString(), isNot(contains('raw-refresh-token')));
    });
  });
}

void expectLogoutStateToBeRedacted(AuthState state) {
  expect(state.toString(), isNot(contains('user-id')));
  expect(state.toString(), isNot(contains('Ada Lovelace')));
  expect(
    state.toString(),
    isNot(contains('https://example.com/avatar.png')),
  );
  expect(state.toString(), isNot(contains('signed-access-token')));
  expect(state.toString(), isNot(contains('raw-refresh-token')));
}

final AuthSession session = AuthSession(
  user: AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: 'https://example.com/avatar.png',
  ),
  tokens: AuthTokens(
    accessToken: 'signed-access-token',
    refreshToken: 'raw-refresh-token',
  ),
);
