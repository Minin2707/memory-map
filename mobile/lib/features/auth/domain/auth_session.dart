import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

final class AuthSession {
  const AuthSession({
    required this.user,
    required this.tokens,
  });

  final AuthUser user;
  final AuthTokens tokens;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthSession &&
            user == other.user &&
            tokens == other.tokens;
  }

  @override
  int get hashCode => Object.hash(
        user,
        tokens,
      );

  @override
  String toString() => 'AuthSession[REDACTED]';
}
