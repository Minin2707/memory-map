import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_data_source.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_exception.dart';
import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/google_identity_exception.dart';
import 'package:memory_map/features/auth/domain/google_identity_provider.dart';

final class DefaultAuthRepository implements AuthRepository {
  const DefaultAuthRepository({
    required GoogleIdentityProvider googleIdentityProvider,
    required AuthRemoteDataSource authRemoteDataSource,
    required AuthSessionStorage authSessionStorage,
  })  : _googleIdentityProvider = googleIdentityProvider,
        _authRemoteDataSource = authRemoteDataSource,
        _authSessionStorage = authSessionStorage;

  final GoogleIdentityProvider _googleIdentityProvider;
  final AuthRemoteDataSource _authRemoteDataSource;
  final AuthSessionStorage _authSessionStorage;

  @override
  Future<AuthSession> loginWithGoogle() async {
    final idToken = await _requestGoogleIdToken();
    final session = await _loginWithBackend(idToken);

    await _writeSession(session);

    return session;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final storedSession = await _readStoredSession();
    if (storedSession == null) {
      return null;
    }

    final AuthTokens refreshedTokens;
    try {
      refreshedTokens = await _refreshStoredSession(storedSession);
    } on _NoRestoredSession {
      return null;
    }
    final refreshedSession = AuthSession(
      user: storedSession.user,
      tokens: refreshedTokens,
    );

    await _writeRefreshedSession(refreshedSession);

    return refreshedSession;
  }

  @override
  Future<void> logout(AuthSession session) async {
    final refreshToken = session.tokens.refreshToken;

    await _clearSessionForLogout();

    try {
      await _authRemoteDataSource.logout(refreshToken);
    } on AuthRemoteException {
      // Remote logout is best-effort after local secrets are cleared.
    }
  }

  Future<String> _requestGoogleIdToken() async {
    try {
      return await _googleIdentityProvider.requestIdToken();
    } on GoogleIdentityCancelledException {
      throw const AuthApplicationException(AuthCancelled());
    } on GoogleIdentityUnavailableException {
      throw const AuthApplicationException(
        GoogleAuthenticationUnavailable(),
      );
    } on GoogleIdentityAuthenticationException {
      throw const AuthApplicationException(
        GoogleAuthenticationFailed(),
      );
    }
  }

  Future<AuthSession> _loginWithBackend(String idToken) async {
    try {
      return await _authRemoteDataSource.loginWithGoogle(idToken);
    } on AuthRemoteUnauthorizedException {
      throw const AuthApplicationException(BackendUnauthorized());
    } on AuthRemoteValidationException {
      throw const AuthApplicationException(RequestValidationFailed());
    } on AuthRemoteNetworkException {
      throw const AuthApplicationException(NetworkUnavailable());
    } on AuthRemoteTimeoutException {
      throw const AuthApplicationException(RequestTimedOut());
    } on AuthRemoteServerException {
      throw const AuthApplicationException(ServerFailure());
    } on AuthRemoteMalformedResponseException {
      throw const AuthApplicationException(UnknownAuthFailure());
    } on AuthRemoteUnknownException {
      throw const AuthApplicationException(UnknownAuthFailure());
    }
  }

  Future<void> _writeSession(AuthSession session) async {
    try {
      await _authSessionStorage.write(session);
    } on CorruptStoredAuthSessionException {
      await _clearAfterWriteFailure();
      throw const AuthApplicationException(CorruptSession());
    } on AuthSessionStorageException {
      await _clearAfterWriteFailure();
      throw const AuthApplicationException(SecureStorageFailure());
    }
  }

  Future<void> _clearAfterWriteFailure() async {
    try {
      await _authSessionStorage.clear();
    } on Exception {
      // Best-effort cleanup must not replace the original storage failure.
    }
  }

  Future<void> _clearSessionForLogout() async {
    try {
      await _authSessionStorage.clear();
    } on CorruptStoredAuthSessionException {
      throw const AuthApplicationException(SecureStorageFailure());
    } on AuthSessionStorageException {
      throw const AuthApplicationException(SecureStorageFailure());
    }
  }

  Future<AuthSession?> _readStoredSession() async {
    try {
      return await _authSessionStorage.read();
    } on CorruptStoredAuthSessionException {
      await _clearCorruptStoredSession();
      return null;
    } on AuthSessionStorageException {
      throw const AuthApplicationException(SecureStorageFailure());
    }
  }

  Future<void> _clearCorruptStoredSession() async {
    try {
      await _authSessionStorage.clear();
    } on AuthSessionStorageException {
      throw const AuthApplicationException(SecureStorageFailure());
    }
  }

  Future<AuthTokens> _refreshStoredSession(AuthSession storedSession) async {
    try {
      return await _authRemoteDataSource.refresh(
        storedSession.tokens.refreshToken,
      );
    } on AuthRemoteUnauthorizedException {
      await _clearUnauthorizedStoredSession();
      throw const _NoRestoredSession();
    } on AuthRemoteValidationException {
      throw const AuthApplicationException(RequestValidationFailed());
    } on AuthRemoteNetworkException {
      throw const AuthApplicationException(NetworkUnavailable());
    } on AuthRemoteTimeoutException {
      throw const AuthApplicationException(RequestTimedOut());
    } on AuthRemoteServerException {
      throw const AuthApplicationException(ServerFailure());
    } on AuthRemoteMalformedResponseException {
      throw const AuthApplicationException(UnknownAuthFailure());
    } on AuthRemoteUnknownException {
      throw const AuthApplicationException(UnknownAuthFailure());
    }
  }

  Future<void> _clearUnauthorizedStoredSession() async {
    try {
      await _authSessionStorage.clear();
    } on AuthSessionStorageException {
      throw const AuthApplicationException(SecureStorageFailure());
    }
  }

  Future<void> _writeRefreshedSession(AuthSession session) async {
    try {
      await _authSessionStorage.write(session);
    } on AuthSessionStorageException {
      await _clearAfterWriteFailure();
      throw const AuthApplicationException(SecureStorageFailure());
    }
  }
}

final class _NoRestoredSession implements Exception {
  const _NoRestoredSession();
}
