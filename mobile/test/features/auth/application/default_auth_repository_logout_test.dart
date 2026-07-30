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
  group('DefaultAuthRepository logout happy path', () {
    test('shouldClearLocalSession', () async {
      final fakes = LogoutFakes();
      final repository = fakes.createRepository();

      await repository.logout(session);

      expect(fakes.storage.clearCalls, 1);
      expect(fakes.storage.session, isNull);
    });

    test('shouldUseCurrentRefreshTokenForRemoteLogout', () async {
      final fakes = LogoutFakes();
      final repository = fakes.createRepository();

      await repository.logout(session);

      expect(fakes.remote.receivedRefreshToken, rawRefreshToken);
    });

    test('shouldCallClearBeforeRemoteLogout', () async {
      final calls = <String>[];
      final fakes = LogoutFakes(calls: calls);
      final repository = fakes.createRepository();

      await repository.logout(session);

      expect(calls, <String>[
        'storage.clear',
        'remote.logout',
      ]);
    });

    test('shouldCompleteLogout', () async {
      final fakes = LogoutFakes();
      final repository = fakes.createRepository();

      await expectLater(repository.logout(session), completes);
    });

    test('shouldNotReadStorageDuringLogout', () async {
      final fakes = LogoutFakes();
      final repository = fakes.createRepository();

      await repository.logout(session);

      expect(fakes.storage.readCalls, 0);
    });
  });

  group('DefaultAuthRepository logout local failure', () {
    test('shouldMapStorageClearFailure', () async {
      final fakes = LogoutFakes()
        ..storage.clearFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectApplicationFailure(
        repository.logout(session),
        const SecureStorageFailure(),
      );
    });

    test('shouldMapCorruptStorageClearFailureToSecureStorageFailure',
        () async {
      final fakes = LogoutFakes()
        ..storage.clearFailure = const CorruptStoredAuthSessionException();
      final repository = fakes.createRepository();

      await expectApplicationFailure(
        repository.logout(session),
        const SecureStorageFailure(),
      );
    });

    test('shouldNotCallRemoteWhenStorageClearFails', () async {
      final fakes = LogoutFakes()
        ..storage.clearFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.logout(session),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.remote.logoutCalls, 0);
    });

    test('shouldNotConsiderLogoutSuccessfulWhenLocalClearFails', () async {
      final fakes = LogoutFakes()
        ..storage.clearFailure = const AuthSessionStorageException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.logout(session),
        throwsA(isA<AuthApplicationException>()),
      );

      expect(fakes.storage.session, session);
    });
  });

  group('DefaultAuthRepository logout remote best effort', () {
    test('shouldIgnoreRemoteUnauthorizedAfterLocalClear', () async {
      await expectRemoteLogoutFailureIsIgnored(
        const AuthRemoteUnauthorizedException(),
      );
    });

    test('shouldIgnoreRemoteValidationFailureAfterLocalClear', () async {
      await expectRemoteLogoutFailureIsIgnored(
        const AuthRemoteValidationException(),
      );
    });

    test('shouldIgnoreRemoteNetworkFailureAfterLocalClear', () async {
      await expectRemoteLogoutFailureIsIgnored(
        const AuthRemoteNetworkException(),
      );
    });

    test('shouldIgnoreRemoteTimeoutAfterLocalClear', () async {
      await expectRemoteLogoutFailureIsIgnored(
        const AuthRemoteTimeoutException(),
      );
    });

    test('shouldIgnoreRemoteServerFailureAfterLocalClear', () async {
      await expectRemoteLogoutFailureIsIgnored(
        const AuthRemoteServerException(),
      );
    });

    test('shouldIgnoreMalformedRemoteResponseAfterLocalClear', () async {
      await expectRemoteLogoutFailureIsIgnored(
        const AuthRemoteMalformedResponseException(),
      );
    });

    test('shouldIgnoreUnknownRemoteFailureAfterLocalClear', () async {
      await expectRemoteLogoutFailureIsIgnored(
        const AuthRemoteUnknownException(),
      );
    });
  });

  group('DefaultAuthRepository logout security', () {
    test('shouldNotPersistOrLogRefreshToken', () async {
      final fakes = LogoutFakes();
      final repository = fakes.createRepository();

      await repository.logout(session);

      expect(fakes.storage.writeCalls, 0);
      expect(repository.toString(), isNot(contains(rawRefreshToken)));
      expect(repository.toString(), isNot(contains(signedAccessToken)));
    });

    test('shouldNotCallGoogleIdentityProviderDuringLogout', () async {
      final fakes = LogoutFakes();
      final repository = fakes.createRepository();

      await repository.logout(session);

      expect(fakes.google.requestCalls, 0);
    });
  });

  group('DefaultAuthRepository logout unexpected exception', () {
    test('shouldNotMaskUnexpectedStorageException', () async {
      final fakes = LogoutFakes()
        ..storage.clearFailure = const UnexpectedLogoutException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.logout(session),
        throwsA(isA<UnexpectedLogoutException>()),
      );
    });

    test('shouldNotMaskUnexpectedRemoteException', () async {
      final fakes = LogoutFakes()
        ..remote.logoutFailure = const UnexpectedLogoutException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.logout(session),
        throwsA(isA<UnexpectedLogoutException>()),
      );
      expect(fakes.storage.session, isNull);
    });
  });
}

Future<void> expectRemoteLogoutFailureIsIgnored(
  AuthRemoteException exception,
) async {
  final fakes = LogoutFakes()
    ..remote.logoutFailure = exception;
  final repository = fakes.createRepository();

  await repository.logout(session);

  expect(fakes.storage.session, isNull);
  expect(fakes.remote.logoutCalls, 1);
}

Future<void> expectApplicationFailure(
  Future<void> future,
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

const String signedAccessToken = 'signed-access-token';
const String rawRefreshToken = 'raw-refresh-token';

final AuthSession session = AuthSession(
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

final class LogoutFakes {
  LogoutFakes({List<String>? calls}) : calls = calls ?? <String>[];

  final List<String> calls;

  late final FakeGoogleIdentityProvider google =
      FakeGoogleIdentityProvider();
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
  int requestCalls = 0;

  @override
  Future<String> requestIdToken() async {
    requestCalls += 1;

    return 'raw-google-id-token';
  }
}

final class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  FakeAuthRemoteDataSource(this.calls);

  final List<String> calls;
  int logoutCalls = 0;
  String? receivedRefreshToken;
  Object? logoutFailure;

  @override
  Future<AuthSession> loginWithGoogle(String idToken) {
    throw UnimplementedError();
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout(String refreshToken) async {
    calls.add('remote.logout');
    logoutCalls += 1;
    receivedRefreshToken = refreshToken;

    final failure = logoutFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

final class FakeAuthSessionStorage implements AuthSessionStorage {
  FakeAuthSessionStorage(this.calls);

  final List<String> calls;
  int readCalls = 0;
  int writeCalls = 0;
  int clearCalls = 0;
  AuthSession? session = sessionFixture;
  Object? clearFailure;

  @override
  Future<AuthSession?> read() async {
    readCalls += 1;

    return session;
  }

  @override
  Future<void> write(AuthSession session) async {
    writeCalls += 1;
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

final AuthSession sessionFixture = session;

final class UnexpectedLogoutException implements Exception {
  const UnexpectedLogoutException();
}
