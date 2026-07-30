import 'package:memory_map/features/auth/domain/auth_session.dart';

abstract interface class AuthorizedSessionManager {
  Future<AuthSession?> getCurrentSession();

  Future<AuthSession> refreshCurrentSession(AuthSession currentSession);

  Future<void> invalidateCurrentSession(AuthSession currentSession);
}
