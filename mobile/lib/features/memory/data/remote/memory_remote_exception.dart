sealed class MemoryRemoteException implements Exception {
  const MemoryRemoteException();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryRemoteException && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class MemoryRemoteValidationException extends MemoryRemoteException {
  const MemoryRemoteValidationException();
}

final class MemoryRemoteUnauthorizedException extends MemoryRemoteException {
  const MemoryRemoteUnauthorizedException();
}

final class MemoryRemoteStoryUnavailableException
    extends MemoryRemoteException {
  const MemoryRemoteStoryUnavailableException();
}

final class MemoryRemoteNotFoundException extends MemoryRemoteException {
  const MemoryRemoteNotFoundException();
}

final class MemoryRemoteCreationUnavailableException
    extends MemoryRemoteException {
  const MemoryRemoteCreationUnavailableException();
}

final class MemoryRemoteUpdateUnavailableException
    extends MemoryRemoteException {
  const MemoryRemoteUpdateUnavailableException();
}

final class MemoryRemoteDeletionUnavailableException
    extends MemoryRemoteException {
  const MemoryRemoteDeletionUnavailableException();
}

final class MemoryRemoteNetworkException extends MemoryRemoteException {
  const MemoryRemoteNetworkException();
}

final class MemoryRemoteTimeoutException extends MemoryRemoteException {
  const MemoryRemoteTimeoutException();
}

final class MemoryRemoteServerException extends MemoryRemoteException {
  const MemoryRemoteServerException();
}

final class MemoryRemoteMalformedResponseException
    extends MemoryRemoteException {
  const MemoryRemoteMalformedResponseException();
}

final class MemoryRemoteUnknownException extends MemoryRemoteException {
  const MemoryRemoteUnknownException();
}
