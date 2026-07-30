import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is AuthUnauthenticated;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AuthUnauthenticated';
}

final class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is AuthAuthenticating;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AuthAuthenticating';
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  final AuthSession session;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthAuthenticated && session == other.session;
  }

  @override
  int get hashCode => Object.hash(
        AuthAuthenticated,
        session,
      );

  @override
  String toString() => 'AuthAuthenticated[REDACTED]';
}

final class AuthLoggingOut extends AuthState {
  const AuthLoggingOut(this.session);

  final AuthSession session;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthLoggingOut && session == other.session;
  }

  @override
  int get hashCode => Object.hash(
        AuthLoggingOut,
        session,
      );

  @override
  String toString() => 'AuthLoggingOut[REDACTED]';
}

final class AuthLogoutFailure extends AuthState {
  const AuthLogoutFailure({
    required this.session,
    required this.failure,
  });

  final AuthSession session;
  final AuthFailure failure;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthLogoutFailure &&
            session == other.session &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        AuthLogoutFailure,
        session,
        failure,
      );

  @override
  String toString() => 'AuthLogoutFailure[REDACTED]';
}

final class AuthRestoreFailure extends AuthState {
  const AuthRestoreFailure(this.failure);

  final AuthFailure failure;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthRestoreFailure && failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        AuthRestoreFailure,
        failure,
      );

  @override
  String toString() => 'AuthRestoreFailure';
}

final class AuthLoginFailure extends AuthState {
  const AuthLoginFailure(this.failure);

  final AuthFailure failure;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthLoginFailure && failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        AuthLoginFailure,
        failure,
      );

  @override
  String toString() => 'AuthLoginFailure';
}
