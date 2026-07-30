import 'package:memory_map/features/auth/domain/auth_session.dart';

abstract interface class AuthSessionStore {
  AuthSession? get session;

  Stream<AuthSession?> get changes;

  void setSession(AuthSession session);

  void clear();
}
