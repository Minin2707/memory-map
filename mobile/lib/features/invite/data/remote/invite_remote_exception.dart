sealed class InviteRemoteException implements Exception {
  const InviteRemoteException();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InviteRemoteException && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class InviteRemoteUnauthorizedException extends InviteRemoteException {
  const InviteRemoteUnauthorizedException();
}

final class InviteRemoteValidationException extends InviteRemoteException {
  const InviteRemoteValidationException();
}

final class InviteRemoteNotFoundException extends InviteRemoteException {
  const InviteRemoteNotFoundException();
}

final class InviteRemoteNetworkException extends InviteRemoteException {
  const InviteRemoteNetworkException();
}

final class InviteRemoteTimeoutException extends InviteRemoteException {
  const InviteRemoteTimeoutException();
}

final class InviteRemoteServerException extends InviteRemoteException {
  const InviteRemoteServerException();
}

final class InviteRemoteMalformedResponseException
    extends InviteRemoteException {
  const InviteRemoteMalformedResponseException();
}

final class InviteRemoteUnknownException extends InviteRemoteException {
  const InviteRemoteUnknownException();
}
