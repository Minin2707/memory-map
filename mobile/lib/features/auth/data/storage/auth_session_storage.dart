import 'package:memory_map/features/auth/domain/auth_session.dart';

abstract interface class AuthSessionStorage {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

class AuthSessionStorageException implements Exception {
  const AuthSessionStorageException();

  @override
  String toString() => 'AuthSessionStorageException';
}

final class CorruptStoredAuthSessionException
    extends AuthSessionStorageException {
  const CorruptStoredAuthSessionException();

  @override
  String toString() => 'CorruptStoredAuthSessionException';
}
