import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

abstract interface class AuthorizedSessionManager {
  Future<AuthSession?> getCurrentSession();

  Future<AuthSession> refreshCurrentSession(AuthSession currentSession);

  Future<void> invalidateCurrentSession(AuthSession currentSession);

  Future<AuthSession?> updateCurrentSessionUserIfStillCurrent({
    required AuthSession expectedSession,
    required AuthUser updatedUser,
  });
}
