sealed class MediaRemoteException implements Exception {
  const MediaRemoteException();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MediaRemoteException && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class MediaRemoteValidationException extends MediaRemoteException {
  const MediaRemoteValidationException();
}

final class MediaRemoteUnauthorizedException extends MediaRemoteException {
  const MediaRemoteUnauthorizedException();
}

final class MediaRemoteUnavailableException extends MediaRemoteException {
  const MediaRemoteUnavailableException();
}

final class MediaRemoteUploadUnavailableException
    extends MediaRemoteException {
  const MediaRemoteUploadUnavailableException();
}

final class MediaRemoteNetworkException extends MediaRemoteException {
  const MediaRemoteNetworkException();
}

final class MediaRemoteTimeoutException extends MediaRemoteException {
  const MediaRemoteTimeoutException();
}

final class MediaRemoteServerException extends MediaRemoteException {
  const MediaRemoteServerException();
}

final class MediaRemoteMalformedResponseException
    extends MediaRemoteException {
  const MediaRemoteMalformedResponseException();
}

final class MediaRemoteUnknownException extends MediaRemoteException {
  const MediaRemoteUnknownException();
}
