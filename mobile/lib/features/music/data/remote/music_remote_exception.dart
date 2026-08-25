sealed class MusicRemoteException implements Exception {
  const MusicRemoteException();

  @override
  String toString() => runtimeType.toString();
}

final class MusicRemoteValidationException extends MusicRemoteException {
  const MusicRemoteValidationException();
}

final class MusicRemoteUnauthorizedException extends MusicRemoteException {
  const MusicRemoteUnauthorizedException();
}

final class MusicRemoteUnavailableException extends MusicRemoteException {
  const MusicRemoteUnavailableException();
}

final class MusicRemoteNetworkException extends MusicRemoteException {
  const MusicRemoteNetworkException();
}

final class MusicRemoteTimeoutException extends MusicRemoteException {
  const MusicRemoteTimeoutException();
}

final class MusicRemoteServerException extends MusicRemoteException {
  const MusicRemoteServerException();
}

final class MusicRemoteMalformedResponseException extends MusicRemoteException {
  const MusicRemoteMalformedResponseException();
}

final class MusicRemoteUnknownException extends MusicRemoteException {
  const MusicRemoteUnknownException();
}
