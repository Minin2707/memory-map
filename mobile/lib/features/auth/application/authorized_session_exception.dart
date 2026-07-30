sealed class AuthorizedSessionException implements Exception {
  const AuthorizedSessionException();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthorizedSessionException &&
            other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class AuthorizedSessionUnavailableException
    extends AuthorizedSessionException {
  const AuthorizedSessionUnavailableException();
}

final class AuthorizedSessionInvalidException
    extends AuthorizedSessionException {
  const AuthorizedSessionInvalidException();
}

final class AuthorizedSessionRefreshException
    extends AuthorizedSessionException {
  const AuthorizedSessionRefreshException();
}

final class AuthorizedSessionPersistenceException
    extends AuthorizedSessionException {
  const AuthorizedSessionPersistenceException();
}
