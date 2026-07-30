import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  group('AuthNotifier startup', () {
    test('shouldStartWithAsyncLoading', () async {
      final restoreCompleter = Completer<AuthSession?>();
      final fakeRepository = FakeAuthRepository()
        ..restoreCompleter = restoreCompleter;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);

      final future = container.read(authNotifierProvider.future);

      expect(
        container.read(authNotifierProvider),
        isA<AsyncLoading<AuthState>>(),
      );

      restoreCompleter.complete(null);
      await future;
    });

    test('shouldBecomeUnauthenticatedWhenNoSessionExists', () async {
      final container = createContainer(FakeAuthRepository());
      addTearDown(container.dispose);

      final state = await container.read(authNotifierProvider.future);

      expect(state, const AuthUnauthenticated());
    });

    test('shouldBecomeAuthenticatedAfterSuccessfulRestore', () async {
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);

      final state = await container.read(authNotifierProvider.future);

      expect(state, AuthAuthenticated(session));
    });

    test('shouldExposeRestoreFailure', () async {
      final fakeRepository = FakeAuthRepository()
        ..restoreFailure = const AuthApplicationException(
          NetworkUnavailable(),
        );
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);

      final state = await container.read(authNotifierProvider.future);

      expect(state, const AuthRestoreFailure(NetworkUnavailable()));
    });

    test('shouldExposeUnexpectedRestoreExceptionAsAsyncError', () async {
      final fakeRepository = FakeAuthRepository()
        ..restoreFailure = const UnexpectedAuthException();
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      final errorState = Completer<AsyncValue<AuthState>>();
      final subscription = container.listen(
        authNotifierProvider,
        (previous, next) {
          if (next.hasError && !errorState.isCompleted) {
            errorState.complete(next);
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final state = await errorState.future;

      expect(state.hasError, isTrue);
      expect(state.error, isA<UnexpectedAuthException>());
    });
  });

  group('AuthNotifier retry restore', () {
    test('shouldRetrySessionRestore', () async {
      final fakeRepository = FakeAuthRepository();
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container
          .read(authNotifierProvider.notifier)
          .retrySessionRestore();

      expect(fakeRepository.restoreCalls, 2);
    });

    test('shouldShowLoadingDuringRetry', () async {
      final retryCompleter = Completer<AuthSession?>();
      final fakeRepository = FakeAuthRepository();
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);
      fakeRepository.restoreCompleter = retryCompleter;

      final retry = container
          .read(authNotifierProvider.notifier)
          .retrySessionRestore();
      await pumpEventQueue();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncLoading<AuthState>>(),
      );

      retryCompleter.complete(null);
      await retry;
    });

    test('shouldBecomeAuthenticatedAfterSuccessfulRetry', () async {
      final fakeRepository = FakeAuthRepository();
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);
      fakeRepository.restoreResult = session;

      await container
          .read(authNotifierProvider.notifier)
          .retrySessionRestore();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<AuthState>>().having(
          (value) => value.value,
          'value',
          AuthAuthenticated(session),
        ),
      );
    });

    test('shouldIgnoreConcurrentRetryWhileLoading', () async {
      final retryCompleter = Completer<AuthSession?>();
      final fakeRepository = FakeAuthRepository();
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);
      fakeRepository.restoreCompleter = retryCompleter;

      final notifier = container.read(authNotifierProvider.notifier);
      final firstRetry = notifier.retrySessionRestore();
      await pumpEventQueue();
      await notifier.retrySessionRestore();

      expect(fakeRepository.restoreCalls, 2);

      retryCompleter.complete(null);
      await firstRetry;
    });
  });

  group('AuthNotifier login', () {
    test('shouldExposeAuthenticatingStateDuringGoogleLogin', () async {
      final loginCompleter = Completer<AuthSession>();
      final fakeRepository = FakeAuthRepository()
        ..loginCompleter = loginCompleter;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      final login = container
          .read(authNotifierProvider.notifier)
          .loginWithGoogle();
      await pumpEventQueue();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<AuthState>>().having(
          (value) => value.value,
          'value',
          const AuthAuthenticating(),
        ),
      );

      loginCompleter.complete(session);
      await login;
    });

    test('shouldBecomeAuthenticatedAfterSuccessfulLogin', () async {
      final fakeRepository = FakeAuthRepository();
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).loginWithGoogle();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<AuthState>>().having(
          (value) => value.value,
          'value',
          AuthAuthenticated(session),
        ),
      );
    });

    test('shouldReturnToUnauthenticatedAfterGoogleCancellation', () async {
      final fakeRepository = FakeAuthRepository()
        ..loginFailure = const AuthApplicationException(AuthCancelled());
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).loginWithGoogle();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<AuthState>>().having(
          (value) => value.value,
          'value',
          const AuthUnauthenticated(),
        ),
      );
    });

    test('shouldExposeLoginFailureForKnownFailure', () async {
      final fakeRepository = FakeAuthRepository()
        ..loginFailure = const AuthApplicationException(ServerFailure());
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).loginWithGoogle();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<AuthState>>().having(
          (value) => value.value,
          'value',
          const AuthLoginFailure(ServerFailure()),
        ),
      );
    });

    test('shouldExposeUnexpectedLoginExceptionAsAsyncError', () async {
      final fakeRepository = FakeAuthRepository()
        ..loginFailure = const UnexpectedAuthException();
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).loginWithGoogle();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncError<AuthState>>(),
      );
    });

    test('shouldIgnoreSecondLoginWhileAlreadyAuthenticating', () async {
      final loginCompleter = Completer<AuthSession>();
      final fakeRepository = FakeAuthRepository()
        ..loginCompleter = loginCompleter;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      final notifier = container.read(authNotifierProvider.notifier);
      final firstLogin = notifier.loginWithGoogle();
      await pumpEventQueue();
      await notifier.loginWithGoogle();

      expect(fakeRepository.loginCalls, 1);

      loginCompleter.complete(session);
      await firstLogin;
    });

    test('shouldNotStartLoginWhileRestoreIsLoading', () async {
      final restoreCompleter = Completer<AuthSession?>();
      final fakeRepository = FakeAuthRepository()
        ..restoreCompleter = restoreCompleter;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);

      final future = container.read(authNotifierProvider.future);
      await pumpEventQueue();
      await container.read(authNotifierProvider.notifier).loginWithGoogle();

      expect(fakeRepository.loginCalls, 0);

      restoreCompleter.complete(null);
      await future;
    });
  });

  group('AuthNotifier logout', () {
    test('shouldPassCurrentSessionToRepositoryLogout', () async {
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).logout();

      expect(fakeRepository.logoutSession, session);
    });

    test('shouldExposeLoggingOutState', () async {
      final logoutCompleter = Completer<void>();
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session
        ..logoutCompleter = logoutCompleter;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      final logout = container.read(authNotifierProvider.notifier).logout();
      await pumpEventQueue();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<AuthState>>().having(
          (value) => value.value,
          'value',
          AuthLoggingOut(session),
        ),
      );

      logoutCompleter.complete();
      await logout;
    });

    test('shouldBecomeUnauthenticatedAfterSuccessfulLogout', () async {
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).logout();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<AuthState>>().having(
          (value) => value.value,
          'value',
          const AuthUnauthenticated(),
        ),
      );
    });

    test('shouldExposeLogoutFailureWhenLocalLogoutFails', () async {
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session
        ..logoutFailure = const AuthApplicationException(
          SecureStorageFailure(),
        );
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).logout();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<AuthState>>().having(
          (value) => value.value,
          'value',
          AuthLogoutFailure(
            session: session,
            failure: const SecureStorageFailure(),
          ),
        ),
      );
    });

    test('shouldPreserveSessionInLogoutFailure', () async {
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session
        ..logoutFailure = const AuthApplicationException(
          SecureStorageFailure(),
        );
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).logout();

      final authState = container.read(authNotifierProvider).asData?.value;

      expect(authState, isA<AuthLogoutFailure>());
      expect((authState as AuthLogoutFailure).session, session);
    });

    test('shouldRetryLogoutFromLogoutFailure', () async {
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session
        ..logoutFailure = const AuthApplicationException(
          SecureStorageFailure(),
        );
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);
      await container.read(authNotifierProvider.notifier).logout();
      fakeRepository.logoutFailure = null;

      await container.read(authNotifierProvider.notifier).logout();

      expect(fakeRepository.logoutCalls, 2);
      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<AuthState>>().having(
          (value) => value.value,
          'value',
          const AuthUnauthenticated(),
        ),
      );
    });

    test('shouldIgnoreSecondLogoutWhileLoggingOut', () async {
      final logoutCompleter = Completer<void>();
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session
        ..logoutCompleter = logoutCompleter;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      final notifier = container.read(authNotifierProvider.notifier);
      final firstLogout = notifier.logout();
      await pumpEventQueue();
      await notifier.logout();

      expect(fakeRepository.logoutCalls, 1);

      logoutCompleter.complete();
      await firstLogout;
    });

    test('shouldIgnoreLogoutWhenUnauthenticated', () async {
      final fakeRepository = FakeAuthRepository();
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).logout();

      expect(fakeRepository.logoutCalls, 0);
    });

    test('shouldIgnoreLogoutDuringStartupLoading', () async {
      final restoreCompleter = Completer<AuthSession?>();
      final fakeRepository = FakeAuthRepository()
        ..restoreCompleter = restoreCompleter;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);

      final restore = container.read(authNotifierProvider.future);
      await pumpEventQueue();
      await container.read(authNotifierProvider.notifier).logout();

      expect(fakeRepository.logoutCalls, 0);

      restoreCompleter.complete(session);
      await restore;
    });

    test('shouldIgnoreLogoutWhileAuthenticating', () async {
      final loginCompleter = Completer<AuthSession>();
      final fakeRepository = FakeAuthRepository()
        ..loginCompleter = loginCompleter;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      final login = container
          .read(authNotifierProvider.notifier)
          .loginWithGoogle();
      await pumpEventQueue();
      await container.read(authNotifierProvider.notifier).logout();

      expect(fakeRepository.logoutCalls, 0);

      loginCompleter.complete(session);
      await login;
    });

    test('shouldExposeUnexpectedLogoutExceptionAsAsyncError', () async {
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session
        ..logoutFailure = const UnexpectedAuthException();
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).logout();

      expect(
        container.read(authNotifierProvider),
        isA<AsyncError<AuthState>>(),
      );
    });

    test('shouldNotExposeTokensThroughLogoutStates', () async {
      final logoutCompleter = Completer<void>();
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session
        ..logoutCompleter = logoutCompleter;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      final logout = container.read(authNotifierProvider.notifier).logout();
      await pumpEventQueue();

      final loggingOutState = container.read(authNotifierProvider).toString();
      expect(loggingOutState, isNot(contains('signed-access-token')));
      expect(loggingOutState, isNot(contains('raw-refresh-token')));
      expect(loggingOutState, isNot(contains('user-id')));
      expect(loggingOutState, isNot(contains('Ada Lovelace')));

      logoutCompleter.complete();
      await logout;

      fakeRepository.logoutFailure = const AuthApplicationException(
        SecureStorageFailure(),
      );
      fakeRepository.logoutCompleter = null;
      fakeRepository.restoreResult = session;
      await container
          .read(authNotifierProvider.notifier)
          .retrySessionRestore();
      await container.read(authNotifierProvider.notifier).logout();

      final failureState = container.read(authNotifierProvider).toString();
      expect(failureState, isNot(contains('signed-access-token')));
      expect(failureState, isNot(contains('raw-refresh-token')));
      expect(failureState, isNot(contains('user-id')));
      expect(failureState, isNot(contains('Ada Lovelace')));
    });
  });

  group('AuthNotifier security', () {
    test('shouldNotExposeSessionTokensThroughNotifierStateToString', () async {
      final fakeRepository = FakeAuthRepository()
        ..restoreResult = session;
      final container = createContainer(fakeRepository);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      final state = container.read(authNotifierProvider).toString();

      expect(state, isNot(contains('signed-access-token')));
      expect(state, isNot(contains('raw-refresh-token')));
      expect(state, isNot(contains('user-id')));
      expect(state, isNot(contains('Ada Lovelace')));
    });
  });
}

ProviderContainer createContainer(FakeAuthRepository fakeRepository) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeRepository),
    ],
  );
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

final class FakeAuthRepository implements AuthRepository {
  int restoreCalls = 0;
  int loginCalls = 0;
  int logoutCalls = 0;

  AuthSession? restoreResult;
  AuthSession? logoutSession;
  Object? restoreFailure;
  Object? loginFailure;
  Object? logoutFailure;
  Completer<AuthSession?>? restoreCompleter;
  Completer<AuthSession>? loginCompleter;
  Completer<void>? logoutCompleter;

  @override
  Future<AuthSession?> restoreSession() async {
    restoreCalls += 1;

    final completer = restoreCompleter;
    if (completer != null) {
      restoreCompleter = null;
      return completer.future;
    }

    final failure = restoreFailure;
    if (failure != null) {
      throw failure;
    }

    return restoreResult;
  }

  @override
  Future<AuthSession> loginWithGoogle() async {
    loginCalls += 1;

    final completer = loginCompleter;
    if (completer != null) {
      return completer.future;
    }

    final failure = loginFailure;
    if (failure != null) {
      throw failure;
    }

    return session;
  }

  @override
  Future<void> logout(AuthSession session) async {
    logoutCalls += 1;
    logoutSession = session;

    final completer = logoutCompleter;
    if (completer != null) {
      return completer.future;
    }

    final failure = logoutFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

final class UnexpectedAuthException implements Exception {
  const UnexpectedAuthException();
}
