sealed class GoogleIdentityException implements Exception {
  const GoogleIdentityException();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GoogleIdentityException && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class GoogleIdentityCancelledException
    extends GoogleIdentityException {
  const GoogleIdentityCancelledException();
}

final class GoogleIdentityUnavailableException
    extends GoogleIdentityException {
  const GoogleIdentityUnavailableException();
}

final class GoogleIdentityAuthenticationException
    extends GoogleIdentityException {
  const GoogleIdentityAuthenticationException();
}
