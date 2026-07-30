import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/application/default_auth_repository.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_data_source.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_exception.dart';
import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/auth/domain/google_identity_provider.dart';

void main() {
  group('DefaultAuthRepository restore no session', () {
    test('shouldReturnNullWhenStoredSessionDoesNotExist', () async {
      final fakes = RestoreFakes()..storage.session = null;
      final repository = fakes.createRepository();

      final session = await repository.restoreSession();

      expect(session, isNull);
    });

    test('shouldNotCallRemoteWhenStoredSessionDoesNotExist', () async {
      final fakes = RestoreFakes()..storage.session = null;
      final repository = fakes.createRepository();

      await repository.restoreSession();

      expect(fakes.remote.refreshCalls, 0);
    });

    test('shouldNotClearStorageWhenStoredSessionDoesNotExist', () async {
      final fakes = RestoreFakes()..storage.session = null;
      final repository = fakes.createRepository();

      await repository.restoreSession();

      expect(fakes.storage.clearCalls, 0);
    });
  });

  group('DefaultAuthRepository restore success', () {
    test('shouldRefreshStoredSession', () async {
      final fakes = RestoreFakes();
      final repository = fakes.createRepository();

      await repository.restoreSession();

      expect(fakes.remote.refreshCalls, 1);
    });

    test('shouldUseStoredRefreshToken', () async {
      final fakes = RestoreFakes();
      final repository = fakes.createRepository();

      await repository.restoreSession();

      expect(fakes.remote.receivedRefreshToken, oldRefreshToken);
    });

    test('shouldPreserveStoredUser', () async {
      final fakes = RestoreFakes();
      final repository = fakes.createRepository();

      final session = await repository.restoreSession();

      expect(session?.user, storedSession.user);
    });

    test('shouldReplaceBothTokensWithRotatedTokens', () async {
      final fakes = RestoreFakes();
      final repository = fakes.createRepository();

      final session = await repository.restoreSession();

      expect(session?.tokens, rotatedTokens);
    });

    test('shouldWriteRefreshedSession', () async {
      final fakes = RestoreFakes();
      final repository = fakes.createRepository();

      await repository.restoreSession();

      expect(fakes.storage.writtenSession, restoredSession);
    });

    test('shouldReturnRefreshedSession', () async {
      final fakes = RestoreFakes();
      final repository = fakes.createRepository();

      final session = await repository.restoreSession();

      expect(session, restoredSession);
    });

    test('shouldCallReadRefreshWriteInOrder', () async {
      final calls = <String>[];
      final fakes = RestoreFakes(calls: calls);
      final repository = fakes.createRepository();

      await repository.restoreSession();

      expect(calls, <String>[
        'storage.read',
        'remote.refresh',
        'storage.write',
      ]);
    });
  });

  group('DefaultAuthRepository invalid restore', () {
    test('shouldClearAndReturnNullForCorruptStoredSession', () async {
      final fakes = RestoreFakes()
        ..storage.readFailure = const CorruptStoredAuthSessionException();
      final repository = fakes.createRepository();

      final session = await repository.restoreSession();

      expect(session, isNull);
      expect(fakes.storage.clearCalls, 1);
    });

    test('shouldReturnStorageFailureWhenCorruptSessionCannotBeCleared',
        () async {
      final fakes = RestoreFakes()
        ..storage.readFailure = const CorruptStoredAuthSessionException()
        ..storage.clearFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectApplicationFailure(
        repository.restoreSession(),
        const SecureStorageFailure(),
      );
    });

    test('shouldClearAndReturnNullForUnauthorizedRefresh', () async {
      final fakes = RestoreFakes()
        ..remote.refreshFailure = const AuthRemoteUnauthorizedException();
      final repository = fakes.createRepository();

      final session = await repository.restoreSession();

      expect(session, isNull);
      expect(fakes.storage.clearCalls, 1);
    });

    test('shouldReturnStorageFailureWhenUnauthorizedSessionCannotBeCleared',
        () async {
      final fakes = RestoreFakes()
        ..remote.refreshFailure = const AuthRemoteUnauthorizedException()
        ..storage.clearFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectApplicationFailure(
        repository.restoreSession(),
        const SecureStorageFailure(),
      );
    });

    test('shouldNotReturnOldSessionAfterUnauthorizedRefresh', () async {
      final fakes = RestoreFakes()
        ..remote.refreshFailure = const AuthRemoteUnauthorizedException();
      final repository = fakes.createRepository();

      final session = await repository.restoreSession();

      expect(session, isNot(storedSession));
      expect(session, isNull);
    });
  });

  group('DefaultAuthRepository recoverable restore failures', () {
    test('shouldMapStorageReadFailure', () async {
      final fakes = RestoreFakes()
        ..storage.readFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectApplicationFailure(
        repository.restoreSession(),
        const SecureStorageFailure(),
      );
    });

    test('shouldMapRefreshValidationFailure', () async {
      await expectRefreshFailure(
        const AuthRemoteValidationException(),
        const RequestValidationFailed(),
      );
    });

    test('shouldMapRefreshNetworkFailure', () async {
      await expectRefreshFailure(
        const AuthRemoteNetworkException(),
        const NetworkUnavailable(),
      );
    });

    test('shouldMapRefreshTimeoutFailure', () async {
      await expectRefreshFailure(
        const AuthRemoteTimeoutException(),
        const RequestTimedOut(),
      );
    });

    test('shouldMapRefreshServerFailure', () async {
      await expectRefreshFailure(
        const AuthRemoteServerException(),
        const ServerFailure(),
      );
    });

    test('shouldMapMalformedRefreshResponse', () async {
      await expectRefreshFailure(
        const AuthRemoteMalformedResponseException(),
        const UnknownAuthFailure(),
      );
    });

    test('shouldMapUnknownRefreshFailure', () async {
      await expectRefreshFailure(
        const AuthRemoteUnknownException(),
        const UnknownAuthFailure(),
      );
    });

    test('shouldPreserveStoredSessionWhenTemporaryRefreshFails', () async {
      final fakes = RestoreFakes()
        ..remote.refreshFailure = const AuthRemoteNetworkException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.restoreSession(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.storage.session, storedSession);
    });

    test('shouldNotWriteSessionWhenRefreshFails', () async {
      final fakes = RestoreFakes()
        ..remote.refreshFailure = const AuthRemoteNetworkException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.restoreSession(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.storage.writeCalls, 0);
    });

    test('shouldNotClearSessionWhenTemporaryRefreshFails', () async {
      final fakes = RestoreFakes()
        ..remote.refreshFailure = const AuthRemoteNetworkException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.restoreSession(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.storage.clearCalls, 0);
    });
  });

  group('DefaultAuthRepository rotated token write failure', () {
    test('shouldMapRefreshedSessionWriteFailure', () async {
      final fakes = RestoreFakes()
        ..storage.writeFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectApplicationFailure(
        repository.restoreSession(),
        const SecureStorageFailure(),
      );
    });

    test('shouldClearStorageWhenRefreshedSessionWriteFails', () async {
      final fakes = RestoreFakes()
        ..storage.writeFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.restoreSession(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.storage.clearCalls, 1);
    });

    test('shouldNotReturnAuthenticatedSessionWhenWriteFails', () async {
      final fakes = RestoreFakes()
        ..storage.writeFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.restoreSession(),
        throwsA(isA<AuthApplicationException>()),
      );
    });

    test('shouldPreserveOriginalWriteFailureWhenClearAlsoFails', () async {
      final fakes = RestoreFakes()
        ..storage.writeFailure = const AuthSessionStorageException()
        ..storage.clearFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectApplicationFailure(
        repository.restoreSession(),
        const SecureStorageFailure(),
      );
      expect(fakes.storage.clearCalls, 1);
    });

    test('shouldNotRetryRefreshWhenWriteFails', () async {
      final fakes = RestoreFakes()
        ..storage.writeFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.restoreSession(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.remote.refreshCalls, 1);
    });
  });

  group('DefaultAuthRepository unexpected restore exception', () {
    test('shouldNotMaskUnexpectedRestoreException', () async {
      final fakes = RestoreFakes()
        ..remote.refreshFailure = const UnexpectedRestoreException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.restoreSession(),
        throwsA(isA<UnexpectedRestoreException>()),
      );
    });
  });
}

Future<void> expectRefreshFailure(
  AuthRemoteException exception,
  AuthFailure failure,
) async {
  final fakes = RestoreFakes()..remote.refreshFailure = exception;
  final repository = fakes.createRepository();

  await expectApplicationFailure(repository.restoreSession(), failure);
}

Future<void> expectApplicationFailure(
  Future<AuthSession?> future,
  AuthFailure failure,
) async {
  await expectLater(
    future,
    throwsA(
      isA<AuthApplicationException>().having(
        (exception) => exception.failure,
        'failure',
        failure,
      ),
    ),
  );
}

const String oldRefreshToken = 'old-refresh-token';
const String newAccessToken = 'new-access-token';
const String newRefreshToken = 'new-refresh-token';

final AuthSession storedSession = AuthSession(
  user: AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: 'https://example.com/avatar.png',
  ),
  tokens: AuthTokens(
    accessToken: 'old-access-token',
    refreshToken: oldRefreshToken,
  ),
);

final AuthTokens rotatedTokens = AuthTokens(
  accessToken: newAccessToken,
  refreshToken: newRefreshToken,
);

final AuthSession restoredSession = AuthSession(
  user: storedSession.user,
  tokens: rotatedTokens,
);

final class RestoreFakes {
  RestoreFakes({List<String>? calls}) : calls = calls ?? <String>[];

  final List<String> calls;

  late final FakeAuthSessionStorage storage = FakeAuthSessionStorage(calls);
  late final FakeAuthRemoteDataSource remote = FakeAuthRemoteDataSource(calls);

  DefaultAuthRepository createRepository() {
    return DefaultAuthRepository(
      googleIdentityProvider: FakeGoogleIdentityProvider(),
      authRemoteDataSource: remote,
      authSessionStorage: storage,
    );
  }
}

final class FakeGoogleIdentityProvider implements GoogleIdentityProvider {
  @override
  Future<String> requestIdToken() {
    throw UnimplementedError();
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
  int readCalls = 0;
  int writeCalls = 0;
  int clearCalls = 0;
  AuthSession? session = storedSession;
  AuthSession? writtenSession;
  Object? readFailure;
  Object? writeFailure;
  Object? clearFailure;

  @override
  Future<AuthSession?> read() async {
    calls.add('storage.read');
    readCalls += 1;

    final failure = readFailure;
    if (failure != null) {
      throw failure;
    }

    return session;
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
    this.session = session;
  }

  @override
  Future<void> clear() async {
    calls.add('storage.clear');
    clearCalls += 1;

    final failure = clearFailure;
    if (failure != null) {
      throw failure;
    }

    session = null;
  }
}

final class UnexpectedRestoreException implements Exception {
  const UnexpectedRestoreException();
}
