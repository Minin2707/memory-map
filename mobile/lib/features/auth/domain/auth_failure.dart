sealed class AuthFailure {
  const AuthFailure();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthFailure && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class AuthCancelled extends AuthFailure {
  const AuthCancelled();
}

final class GoogleAuthenticationUnavailable extends AuthFailure {
  const GoogleAuthenticationUnavailable();
}

final class GoogleAuthenticationFailed extends AuthFailure {
  const GoogleAuthenticationFailed();
}

final class BackendUnauthorized extends AuthFailure {
  const BackendUnauthorized();
}

final class RequestValidationFailed extends AuthFailure {
  const RequestValidationFailed();
}

final class NetworkUnavailable extends AuthFailure {
  const NetworkUnavailable();
}

final class RequestTimedOut extends AuthFailure {
  const RequestTimedOut();
}

final class ServerFailure extends AuthFailure {
  const ServerFailure();
}

final class SecureStorageFailure extends AuthFailure {
  const SecureStorageFailure();
}

final class CorruptSession extends AuthFailure {
  const CorruptSession();
}

final class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure();
}
