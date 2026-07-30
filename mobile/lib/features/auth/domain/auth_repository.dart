import 'package:memory_map/features/auth/domain/auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession> loginWithGoogle();

  Future<AuthSession?> restoreSession();

  Future<void> logout(AuthSession session);
}
