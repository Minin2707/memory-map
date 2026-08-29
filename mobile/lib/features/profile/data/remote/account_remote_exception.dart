sealed class AccountRemoteException implements Exception {
  const AccountRemoteException();
}

final class AccountRemoteOwnershipConflictException
    extends AccountRemoteException {
  const AccountRemoteOwnershipConflictException();
}

final class AccountRemoteValidationException extends AccountRemoteException {
  const AccountRemoteValidationException();
}

final class AccountRemoteUnauthorizedException extends AccountRemoteException {
  const AccountRemoteUnauthorizedException();
}

final class AccountRemoteNetworkException extends AccountRemoteException {
  const AccountRemoteNetworkException();
}

final class AccountRemoteTimeoutException extends AccountRemoteException {
  const AccountRemoteTimeoutException();
}

final class AccountRemoteServerException extends AccountRemoteException {
  const AccountRemoteServerException();
}

final class AccountRemoteUnknownException extends AccountRemoteException {
  const AccountRemoteUnknownException();
}
