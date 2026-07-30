import 'package:memory_map/features/auth/application/authorized_session_exception.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_data_source.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_exception.dart';
import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_session_store.dart';
import 'package:memory_map/features/auth/domain/authorized_session_manager.dart';

final class DefaultAuthorizedSessionManager
    implements AuthorizedSessionManager {
  const DefaultAuthorizedSessionManager({
    required AuthSessionStore authSessionStore,
    required AuthRemoteDataSource authRemoteDataSource,
    required AuthSessionStorage authSessionStorage,
  })  : _authSessionStore = authSessionStore,
        _authRemoteDataSource = authRemoteDataSource,
        _authSessionStorage = authSessionStorage;

  final AuthSessionStore _authSessionStore;
  final AuthRemoteDataSource _authRemoteDataSource;
  final AuthSessionStorage _authSessionStorage;

  @override
  Future<AuthSession?> getCurrentSession() async {
    return _authSessionStore.session;
  }

  @override
  Future<AuthSession> refreshCurrentSession(
    AuthSession currentSession,
  ) async {
    final storedSession = _authSessionStore.session;
    if (storedSession != null && storedSession != currentSession) {
      return storedSession;
    }

    try {
      final tokens = await _authRemoteDataSource.refresh(
        currentSession.tokens.refreshToken,
      );
      final refreshedSession = AuthSession(
        user: currentSession.user,
        tokens: tokens,
      );

      await _writeRotatedSession(refreshedSession);
      _authSessionStore.setSession(refreshedSession);

      return refreshedSession;
    } on AuthRemoteUnauthorizedException {
      await _clearInvalidSession();
      throw const AuthorizedSessionInvalidException();
    } on AuthRemoteException {
      throw const AuthorizedSessionRefreshException();
    }
  }

  @override
  Future<void> invalidateCurrentSession(AuthSession currentSession) async {
    final storedSession = _authSessionStore.session;
    if (storedSession != null && storedSession != currentSession) {
      return;
    }

    await _clearInvalidSession();
  }

  Future<void> _writeRotatedSession(AuthSession session) async {
    try {
      await _authSessionStorage.write(session);
    } on AuthSessionStorageException {
      await _clearAfterWriteFailure();
      _authSessionStore.clear();
      throw const AuthorizedSessionPersistenceException();
    }
  }

  Future<void> _clearAfterWriteFailure() async {
    try {
      await _authSessionStorage.clear();
    } on AuthSessionStorageException {
      // The rotated token pair must not be used when persistence failed.
    }
  }

  Future<void> _clearInvalidSession() async {
    try {
      await _authSessionStorage.clear();
    } on AuthSessionStorageException {
      // Invalid sessions must disappear from memory even if storage cleanup fails.
    }

    _authSessionStore.clear();
  }
}
