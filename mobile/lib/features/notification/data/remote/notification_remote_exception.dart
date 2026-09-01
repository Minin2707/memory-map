sealed class NotificationRemoteException implements Exception {
  const NotificationRemoteException();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotificationRemoteException &&
            other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class NotificationRemoteValidationException
    extends NotificationRemoteException {
  const NotificationRemoteValidationException();
}

final class NotificationRemoteUnauthorizedException
    extends NotificationRemoteException {
  const NotificationRemoteUnauthorizedException();
}

final class NotificationRemoteNotFoundException
    extends NotificationRemoteException {
  const NotificationRemoteNotFoundException();
}

final class NotificationRemoteNetworkException
    extends NotificationRemoteException {
  const NotificationRemoteNetworkException();
}

final class NotificationRemoteTimeoutException
    extends NotificationRemoteException {
  const NotificationRemoteTimeoutException();
}

final class NotificationRemoteServerException
    extends NotificationRemoteException {
  const NotificationRemoteServerException();
}

final class NotificationRemoteMalformedResponseException
    extends NotificationRemoteException {
  const NotificationRemoteMalformedResponseException();
}

final class NotificationRemoteUnknownException
    extends NotificationRemoteException {
  const NotificationRemoteUnknownException();
}
