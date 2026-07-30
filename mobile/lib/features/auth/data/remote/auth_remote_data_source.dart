import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthSession> loginWithGoogle(String idToken);

  Future<AuthTokens> refresh(String refreshToken);

  Future<void> logout(String refreshToken);
}
