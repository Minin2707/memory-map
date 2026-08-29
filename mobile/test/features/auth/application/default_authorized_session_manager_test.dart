import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/authorized_session_exception.dart';
import 'package:memory_map/features/auth/application/default_authorized_session_manager.dart';
import 'package:memory_map/features/auth/application/in_memory_auth_session_store.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_data_source.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_exception.dart';
import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_session_store.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  group('DefaultAuthorizedSessionManager current session', () {
    test('shouldReturnCurrentSession', () async {
      final fakes = ManagerFakes()..store.setSession(session);
      final manager = fakes.createManager();

      final currentSession = await manager.getCurrentSession();

      expect(currentSession, session);
    });

    test('shouldReturnNullWhenSessionUnavailable', () async {
      final fakes = ManagerFakes();
      final manager = fakes.createManager();

      final currentSession = await manager.getCurrentSession();

      expect(currentSession, isNull);
    });
  });

  group('DefaultAuthorizedSessionManager refresh success', () {
    test('shouldRefreshCurrentSession', () async {
      final fakes = ManagerFakes()..store.setSession(session);
      final manager = fakes.createManager();

      final refreshed = await manager.refreshCurrentSession(session);

      expect(refreshed, refreshedSession);
    });

    test('shouldUseCurrentRefreshToken', () async {
      final fakes = ManagerFakes()..store.setSession(session);
      final manager = fakes.createManager();

      await manager.refreshCurrentSession(session);

      expect(fakes.remote.receivedRefreshToken, 'raw-refresh-token');
    });

    test('shouldPreserveUser', () async {
      final fakes = ManagerFakes()..store.setSession(session);
      final manager = fakes.createManager();

      final refreshed = await manager.refreshCurrentSession(session);

      expect(refreshed.user, session.user);
    });

    test('shouldReplaceBothTokens', () async {
      final fakes = ManagerFakes()..store.setSession(session);
      final manager = fakes.createManager();

      final refreshed = await manager.refreshCurrentSession(session);

      expect(refreshed.tokens, rotatedTokens);
    });

    test('shouldWriteRotatedSession', () async {
      final fakes = ManagerFakes()..store.setSession(session);
      final manager = fakes.createManager();

      await manager.refreshCurrentSession(session);

      expect(fakes.storage.writtenSession, refreshedSession);
    });

    test('shouldUpdateInMemoryStore', () async {
      final fakes = ManagerFakes()..store.setSession(session);
      final manager = fakes.createManager();

      await manager.refreshCurrentSession(session);

      expect(fakes.store.session, refreshedSession);
    });

    test('shouldCallRefreshWriteStoreInOrder', () async {
      final calls = <String>[];
      final fakes = ManagerFakes(calls: calls)..store.setSession(session);
      final manager = fakes.createManager();
      calls.clear();

      await manager.refreshCurrentSession(session);

      expect(calls, <String>[
        'remote.refresh',
        'storage.write',
        'store.set',
      ]);
    });
  });

  group('DefaultAuthorizedSessionManager stale session', () {
    test('shouldReuseAlreadyRefreshedSessionWhenFailedSessionIsStale',
        () async {
      final fakes = ManagerFakes()..store.setSession(refreshedSession);
      final manager = fakes.createManager();

      final result = await manager.refreshCurrentSession(session);

      expect(result, refreshedSession);
    });

    test('shouldNotCallRemoteForStaleFailedSession', () async {
      final fakes = ManagerFakes()..store.setSession(refreshedSession);
      final manager = fakes.createManager();

      await manager.refreshCurrentSession(session);

      expect(fakes.remote.refreshCalls, 0);
    });
  });

  group('DefaultAuthorizedSessionManager guarded user update', () {
    test('shouldDropUserUpdateWhenSessionIsUnavailable', () async {
      final fakes = ManagerFakes();
      final manager = fakes.createManager();

      final result = await manager.updateCurrentSessionUserIfStillCurrent(
        expectedSession: session,
        updatedUser: renamedUser,
      );

      expect(result, isNull);
      expect(fakes.storage.writeCalls, 0);
      expect(fakes.store.session, isNull);
    });

    test('shouldDropUserUpdateWhenDifferentUserIsCurrent', () async {
      final fakes = ManagerFakes()..store.setSession(otherSession);
      final manager = fakes.createManager();

      final result = await manager.updateCurrentSessionUserIfStillCurrent(
        expectedSession: session,
        updatedUser: renamedUser,
      );

      expect(result, isNull);
      expect(fakes.storage.writeCalls, 0);
      expect(fakes.store.session, otherSession);
    });

    test('shouldPreserveCurrentTokensWhenSameUserSessionWasRefreshed',
        () async {
      final fakes = ManagerFakes()..store.setSession(refreshedSession);
      final manager = fakes.createManager();

      final result = await manager.updateCurrentSessionUserIfStillCurrent(
        expectedSession: session,
        updatedUser: renamedUser,
      );

      expect(result?.user, renamedUser);
      expect(result?.tokens, rotatedTokens);
      expect(fakes.storage.writtenSession?.tokens, rotatedTokens);
      expect(fakes.store.session?.tokens, rotatedTokens);
    });

    test('shouldDropUserUpdateWhenResponseBelongsToDifferentUser', () async {
      final fakes = ManagerFakes()..store.setSession(session);
      final manager = fakes.createManager();

      final result = await manager.updateCurrentSessionUserIfStillCurrent(
        expectedSession: session,
        updatedUser: otherSession.user,
      );

      expect(result, isNull);
      expect(fakes.storage.writeCalls, 0);
      expect(fakes.store.session, session);
    });

    test('shouldPublishInMemoryUserUpdateWhenStorageWriteFails', () async {
      final fakes = ManagerFakes()
        ..store.setSession(refreshedSession)
        ..storage.writeFailure = const AuthSessionStorageException();
      final manager = fakes.createManager();

      await expectLater(
        manager.updateCurrentSessionUserIfStillCurrent(
          expectedSession: session,
          updatedUser: renamedUser,
        ),
        throwsA(isA<AuthorizedSessionPersistenceException>()),
      );

      expect(fakes.storage.clearCalls, 0);
      expect(fakes.store.session?.user, renamedUser);
      expect(fakes.store.session?.tokens, rotatedTokens);
    });
  });

  group('DefaultAuthorizedSessionManager refresh failure', () {
    test('shouldInvalidateOnUnauthorizedRefresh', () async {
      final fakes = ManagerFakes()
        ..store.setSession(session)
        ..remote.refreshFailure = const AuthRemoteUnauthorizedException();
      final manager = fakes.createManager();

      await expectLater(
        manager.refreshCurrentSession(session),
        throwsA(isA<AuthorizedSessionInvalidException>()),
      );
    });

    test('shouldClearStorageAndStoreOnUnauthorized', () async {
      final fakes = ManagerFakes()
        ..store.setSession(session)
        ..remote.refreshFailure = const AuthRemoteUnauthorizedException();
      final manager = fakes.createManager();

      await expectLater(
        manager.refreshCurrentSession(session),
        throwsA(isA<AuthorizedSessionInvalidException>()),
      );

      expect(fakes.storage.clearCalls, 1);
      expect(fakes.store.session, isNull);
    });

    test('shouldMapTemporaryRefreshFailureWithoutClearing', () async {
      final fakes = ManagerFakes()
        ..store.setSession(session)
        ..remote.refreshFailure = const AuthRemoteNetworkException();
      final manager = fakes.createManager();

      await expectLater(
        manager.refreshCurrentSession(session),
        throwsA(isA<AuthorizedSessionRefreshException>()),
      );

      expect(fakes.storage.clearCalls, 0);
      expect(fakes.store.session, session);
    });

    test('shouldInvalidateWhenRotatedSessionCannotBeWritten', () async {
      final fakes = ManagerFakes()
        ..store.setSession(session)
        ..storage.writeFailure = const AuthSessionStorageException();
      final manager = fakes.createManager();

      await expectLater(
        manager.refreshCurrentSession(session),
        throwsA(isA<AuthorizedSessionPersistenceException>()),
      );

      expect(fakes.storage.clearCalls, 1);
      expect(fakes.store.session, isNull);
    });

    test('shouldPreserveOriginalWriteFailureWhenClearFails', () async {
      final fakes = ManagerFakes()
        ..store.setSession(session)
        ..storage.writeFailure = const AuthSessionStorageException()
        ..storage.clearFailure = const AuthSessionStorageException();
      final manager = fakes.createManager();

      await expectLater(
        manager.refreshCurrentSession(session),
        throwsA(isA<AuthorizedSessionPersistenceException>()),
      );
    });

    test('shouldNotExposeTokensInExceptions', () async {
      final error = const AuthorizedSessionRefreshException();

      expect(error.toString(), isNot(contains('signed-access-token')));
      expect(error.toString(), isNot(contains('raw-refresh-token')));
      expect(error.toString(), isNot(contains('new-access-token')));
    });

    test('shouldNotMaskUnexpectedExceptions', () async {
      final fakes = ManagerFakes()
        ..store.setSession(session)
        ..remote.refreshFailure = const UnexpectedManagerException();
      final manager = fakes.createManager();

      await expectLater(
        manager.refreshCurrentSession(session),
        throwsA(isA<UnexpectedManagerException>()),
      );
    });
  });

  group('DefaultAuthorizedSessionManager explicit invalidation', () {
    test('shouldClearInMemorySessionWhenStorageClearFails', () async {
      final fakes = ManagerFakes()
        ..store.setSession(session)
        ..storage.clearFailure = const AuthSessionStorageException();
      final manager = fakes.createManager();

      await manager.invalidateCurrentSession(session);

      expect(fakes.storage.clearCalls, 1);
      expect(fakes.store.session, isNull);
    });
  });
}

final class ManagerFakes {
  ManagerFakes({List<String>? calls}) : calls = calls ?? <String>[];

  final List<String> calls;

  late final FakeAuthSessionStore store = FakeAuthSessionStore(calls);
  late final FakeAuthRemoteDataSource remote =
      FakeAuthRemoteDataSource(calls);
  late final FakeAuthSessionStorage storage =
      FakeAuthSessionStorage(calls);

  DefaultAuthorizedSessionManager createManager() {
    return DefaultAuthorizedSessionManager(
      authSessionStore: store,
      authRemoteDataSource: remote,
      authSessionStorage: storage,
    );
  }
}

final class FakeAuthSessionStore implements AuthSessionStore {
  FakeAuthSessionStore(this.calls);

  final List<String> calls;
  final InMemoryAuthSessionStore _store = InMemoryAuthSessionStore();

  @override
  AuthSession? get session => _store.session;

  @override
  Stream<AuthSession?> get changes => _store.changes;

  @override
  void setSession(AuthSession session) {
    calls.add('store.set');
    _store.setSession(session);
  }

  @override
  void clear() {
    calls.add('store.clear');
    _store.clear();
  }
}

final class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  FakeAuthRemoteDataSource(this.calls);

  final List<String> calls;
  int refreshCalls = 0;
  String? receivedRefreshToken;
  Object? refreshFailure;

  @override
  Future<AuthSession> loginWithGoogle(String idToken) {
    throw UnimplementedError();
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    calls.add('remote.refresh');
    refreshCalls += 1;
    receivedRefreshToken = refreshToken;

    final failure = refreshFailure;
    if (failure != null) {
      throw failure;
    }

    return rotatedTokens;
  }

  @override
  Future<void> logout(String refreshToken) {
    throw UnimplementedError();
  }
}

final class FakeAuthSessionStorage implements AuthSessionStorage {
  FakeAuthSessionStorage(this.calls);

  final List<String> calls;
  int writeCalls = 0;
  int clearCalls = 0;
  AuthSession? writtenSession;
  Object? writeFailure;
  Object? clearFailure;

  @override
  Future<AuthSession?> read() {
    throw UnimplementedError();
  }

  @override
  Future<void> write(AuthSession session) async {
    calls.add('storage.write');
    writeCalls += 1;

    final failure = writeFailure;
    if (failure != null) {
      throw failure;
    }

    writtenSession = session;
  }

  @override
  Future<void> clear() async {
    calls.add('storage.clear');
    clearCalls += 1;

    final failure = clearFailure;
    if (failure != null) {
      throw failure;
    }
  }
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

final AuthTokens rotatedTokens = AuthTokens(
  accessToken: 'new-access-token',
  refreshToken: 'new-refresh-token',
);

final AuthSession refreshedSession = AuthSession(
  user: session.user,
  tokens: rotatedTokens,
);

final AuthUser renamedUser = AuthUser(
  id: 'user-id',
  displayName: 'Grace Hopper',
  avatarUrl: 'https://example.com/avatar.png',
);

final AuthSession otherSession = AuthSession(
  user: AuthUser(
    id: 'other-user-id',
    displayName: 'Katherine Johnson',
    avatarUrl: 'https://example.com/other-avatar.png',
  ),
  tokens: AuthTokens(
    accessToken: 'other-access-token',
    refreshToken: 'other-refresh-token',
  ),
);

final class UnexpectedManagerException implements Exception {
  const UnexpectedManagerException();
}
