sealed class AuthRemoteException implements Exception {
  const AuthRemoteException();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthRemoteException && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class AuthRemoteUnauthorizedException extends AuthRemoteException {
  const AuthRemoteUnauthorizedException();
}

final class AuthRemoteValidationException extends AuthRemoteException {
  const AuthRemoteValidationException();
}

final class AuthRemoteNetworkException extends AuthRemoteException {
  const AuthRemoteNetworkException();
}

final class AuthRemoteTimeoutException extends AuthRemoteException {
  const AuthRemoteTimeoutException();
}

final class AuthRemoteServerException extends AuthRemoteException {
  const AuthRemoteServerException();
}

final class AuthRemoteMalformedResponseException
    extends AuthRemoteException {
  const AuthRemoteMalformedResponseException();
}

final class AuthRemoteUnknownException extends AuthRemoteException {
  const AuthRemoteUnknownException();
}
