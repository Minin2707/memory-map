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
import 'package:memory_map/features/auth/domain/google_identity_exception.dart';
import 'package:memory_map/features/auth/domain/google_identity_provider.dart';

void main() {
  group('DefaultAuthRepository happy path', () {
    test('shouldRequestGoogleIdToken', () async {
      final fakes = AuthRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.loginWithGoogle();

      expect(fakes.google.requestCalls, 1);
    });

    test('shouldSendGoogleIdTokenToBackend', () async {
      final fakes = AuthRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.loginWithGoogle();

      expect(fakes.remote.receivedIdToken, rawGoogleIdToken);
    });

    test('shouldWriteReturnedSessionToStorage', () async {
      final fakes = AuthRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.loginWithGoogle();

      expect(fakes.storage.writtenSession, backendSession);
    });

    test('shouldReturnStoredAuthSession', () async {
      final fakes = AuthRepositoryFakes();
      final repository = fakes.createRepository();

      final session = await repository.loginWithGoogle();

      expect(session, backendSession);
    });

    test('shouldCallDependenciesInExpectedOrder', () async {
      final calls = <String>[];
      final fakes = AuthRepositoryFakes(calls: calls);
      final repository = fakes.createRepository();

      await repository.loginWithGoogle();

      expect(calls, <String>[
        'google',
        'remote',
        'storage.write',
      ]);
    });

    test('shouldReplaceExistingSessionWithReturnedSession', () async {
      final fakes = AuthRepositoryFakes()
        ..storage.existingSession = oldSession;
      final repository = fakes.createRepository();

      final session = await repository.loginWithGoogle();

      expect(session, backendSession);
      expect(fakes.storage.writtenSession, backendSession);
      expect(fakes.storage.clearCalls, 0);
    });

    test('shouldNotPersistGoogleIdToken', () async {
      final fakes = AuthRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.loginWithGoogle();

      expect(fakes.storage.writtenSession, isNotNull);
      expect(fakes.storage.writtenSession.toString(), 'AuthSession[REDACTED]');
      expect(fakes.storage.receivedRawGoogleIdToken, isFalse);
    });
  });

  group('DefaultAuthRepository Google failure mapping', () {
    test('shouldMapGoogleCancellation', () async {
      await expectGoogleFailure(
        const GoogleIdentityCancelledException(),
        const AuthCancelled(),
      );
    });

    test('shouldMapGoogleUnavailable', () async {
      await expectGoogleFailure(
        const GoogleIdentityUnavailableException(),
        const GoogleAuthenticationUnavailable(),
      );
    });

    test('shouldMapGoogleAuthenticationFailure', () async {
      await expectGoogleFailure(
        const GoogleIdentityAuthenticationException(),
        const GoogleAuthenticationFailed(),
      );
    });

    test('shouldNotCallRemoteWhenGoogleFlowFails', () async {
      final fakes = AuthRepositoryFakes()
        ..google.failure = const GoogleIdentityCancelledException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.remote.loginCalls, 0);
    });

    test('shouldNotWriteStorageWhenGoogleFlowFails', () async {
      final fakes = AuthRepositoryFakes()
        ..google.failure = const GoogleIdentityCancelledException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.storage.writeCalls, 0);
    });

    test('shouldPreserveExistingSessionWhenGoogleFlowFails', () async {
      final fakes = AuthRepositoryFakes()
        ..google.failure = const GoogleIdentityCancelledException()
        ..storage.existingSession = oldSession;
      final repository = fakes.createRepository();

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.storage.clearCalls, 0);
      expect(fakes.storage.existingSession, oldSession);
    });
  });

  group('DefaultAuthRepository remote failure mapping', () {
    test('shouldMapRemoteFailures', () async {
      final cases = <RemoteFailureCase>[
        RemoteFailureCase(
          const AuthRemoteUnauthorizedException(),
          const BackendUnauthorized(),
        ),
        RemoteFailureCase(
          const AuthRemoteValidationException(),
          const RequestValidationFailed(),
        ),
        RemoteFailureCase(
          const AuthRemoteNetworkException(),
          const NetworkUnavailable(),
        ),
        RemoteFailureCase(
          const AuthRemoteTimeoutException(),
          const RequestTimedOut(),
        ),
        RemoteFailureCase(
          const AuthRemoteServerException(),
          const ServerFailure(),
        ),
        RemoteFailureCase(
          const AuthRemoteMalformedResponseException(),
          const UnknownAuthFailure(),
        ),
        RemoteFailureCase(
          const AuthRemoteUnknownException(),
          const UnknownAuthFailure(),
        ),
      ];

      for (final failureCase in cases) {
        await expectRemoteFailure(
          failureCase.exception,
          failureCase.failure,
        );
      }
    });

    test('shouldNotWriteStorageWhenRemoteFails', () async {
      final fakes = AuthRepositoryFakes()
        ..remote.failure = const AuthRemoteNetworkException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.storage.writeCalls, 0);
    });

    test('shouldNotClearExistingSessionWhenRemoteFails', () async {
      final fakes = AuthRepositoryFakes()
        ..remote.failure = const AuthRemoteNetworkException()
        ..storage.existingSession = oldSession;
      final repository = fakes.createRepository();

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.storage.clearCalls, 0);
      expect(fakes.storage.existingSession, oldSession);
    });
  });

  group('DefaultAuthRepository storage failure policy', () {
    test('shouldMapStorageWriteFailure', () async {
      final fakes = AuthRepositoryFakes()
        ..storage.writeFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectApplicationFailure(
        repository.loginWithGoogle(),
        const SecureStorageFailure(),
      );
    });

    test('shouldNotReturnSessionWhenStorageWriteFails', () async {
      final fakes = AuthRepositoryFakes()
        ..storage.writeFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(isA<AuthApplicationException>()),
      );
    });

    test('shouldAttemptClearWhenStorageWriteFails', () async {
      final fakes = AuthRepositoryFakes()
        ..storage.writeFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.storage.clearCalls, 1);
    });

    test('shouldPreserveOriginalStorageFailureWhenClearAlsoFails', () async {
      final fakes = AuthRepositoryFakes()
        ..storage.writeFailure = const AuthSessionStorageException()
        ..storage.clearFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectApplicationFailure(
        repository.loginWithGoogle(),
        const SecureStorageFailure(),
      );
      expect(fakes.storage.clearCalls, 1);
    });

    test('shouldNotCallBackendLogoutWhenStorageWriteFails', () async {
      final fakes = AuthRepositoryFakes()
        ..storage.writeFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.remote.logoutCalls, 0);
    });
  });

  group('DefaultAuthRepository sensitive data', () {
    test('shouldNotExposeSensitiveValuesInApplicationException', () async {
      final fakes = AuthRepositoryFakes()
        ..remote.failure = const AuthRemoteUnauthorizedException();
      final repository = fakes.createRepository();

      try {
        await repository.loginWithGoogle();
        fail('Expected auth application exception');
      } on AuthApplicationException catch (error) {
        expect(error.toString(), 'AuthApplicationException');
        expect(error.toString(), isNot(contains(rawGoogleIdToken)));
        expect(error.toString(), isNot(contains(signedAccessToken)));
        expect(error.toString(), isNot(contains(rawRefreshToken)));
        expect(error.toString(), isNot(contains('google-client-id')));
      }
    });

    test('shouldNotMaskUnexpectedException', () async {
      final fakes = AuthRepositoryFakes()
        ..remote.failure = const UnexpectedTestException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(isA<UnexpectedTestException>()),
      );
    });
  });
}

Future<void> expectGoogleFailure(
  GoogleIdentityException exception,
  AuthFailure failure,
) async {
  final fakes = AuthRepositoryFakes()..google.failure = exception;
  final repository = fakes.createRepository();

  await expectApplicationFailure(
    repository.loginWithGoogle(),
    failure,
  );
}

Future<void> expectRemoteFailure(
  AuthRemoteException exception,
  AuthFailure failure,
) async {
  final fakes = AuthRepositoryFakes()..remote.failure = exception;
  final repository = fakes.createRepository();

  await expectApplicationFailure(
    repository.loginWithGoogle(),
    failure,
  );
}

Future<void> expectApplicationFailure(
  Future<AuthSession> future,
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

const String rawGoogleIdToken = 'raw-google-id-token';
const String signedAccessToken = 'signed-access-token';
const String rawRefreshToken = 'raw-refresh-token';

final AuthSession backendSession = AuthSession(
  user: AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: 'https://example.com/avatar.png',
  ),
  tokens: AuthTokens(
    accessToken: signedAccessToken,
    refreshToken: rawRefreshToken,
  ),
);

final AuthSession oldSession = AuthSession(
  user: AuthUser(
    id: 'old-user-id',
    displayName: 'Grace Hopper',
  ),
  tokens: AuthTokens(
    accessToken: 'old-access-token',
    refreshToken: 'old-refresh-token',
  ),
);

final class AuthRepositoryFakes {
  AuthRepositoryFakes({List<String>? calls}) : calls = calls ?? <String>[];

  final List<String> calls;

  late final FakeGoogleIdentityProvider google =
      FakeGoogleIdentityProvider(calls);
  late final FakeAuthRemoteDataSource remote =
      FakeAuthRemoteDataSource(calls);
  late final FakeAuthSessionStorage storage =
      FakeAuthSessionStorage(calls);

  DefaultAuthRepository createRepository() {
    return DefaultAuthRepository(
      googleIdentityProvider: google,
      authRemoteDataSource: remote,
      authSessionStorage: storage,
    );
  }
}

final class FakeGoogleIdentityProvider implements GoogleIdentityProvider {
  FakeGoogleIdentityProvider(this.calls);

  final List<String> calls;
  int requestCalls = 0;
  Object? failure;

  @override
  Future<String> requestIdToken() async {
    calls.add('google');
    requestCalls += 1;

    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    return rawGoogleIdToken;
  }
}

final class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  FakeAuthRemoteDataSource(this.calls);

  final List<String> calls;
  int loginCalls = 0;
  int logoutCalls = 0;
  String? receivedIdToken;
  Object? failure;

  @override
  Future<AuthSession> loginWithGoogle(String idToken) async {
    calls.add('remote');
    loginCalls += 1;
    receivedIdToken = idToken;

    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    return backendSession;
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout(String refreshToken) async {
    logoutCalls += 1;
  }
}

final class FakeAuthSessionStorage implements AuthSessionStorage {
  FakeAuthSessionStorage(this.calls);

  final List<String> calls;
  int writeCalls = 0;
  int clearCalls = 0;
  AuthSession? writtenSession;
  AuthSession? existingSession;
  Object? writeFailure;
  Object? clearFailure;

  bool get receivedRawGoogleIdToken {
    return writtenSession?.toString().contains(rawGoogleIdToken) ?? false;
  }

  @override
  Future<AuthSession?> read() async {
    return existingSession;
  }

  @override
  Future<void> write(AuthSession session) async {
    calls.add('storage.write');
    writeCalls += 1;

    final configuredFailure = writeFailure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    writtenSession = session;
    existingSession = session;
  }

  @override
  Future<void> clear() async {
    calls.add('storage.clear');
    clearCalls += 1;

    final configuredFailure = clearFailure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    existingSession = null;
  }
}

final class RemoteFailureCase {
  const RemoteFailureCase(this.exception, this.failure);

  final AuthRemoteException exception;
  final AuthFailure failure;
}

final class UnexpectedTestException implements Exception {
  const UnexpectedTestException();
}
