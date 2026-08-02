sealed class StoryRemoteException implements Exception {
  const StoryRemoteException();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryRemoteException && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class StoryRemoteUnauthorizedException extends StoryRemoteException {
  const StoryRemoteUnauthorizedException();
}

final class StoryRemoteValidationException extends StoryRemoteException {
  const StoryRemoteValidationException();
}

final class StoryRemoteNotFoundException extends StoryRemoteException {
  const StoryRemoteNotFoundException();
}

final class StoryRemoteNetworkException extends StoryRemoteException {
  const StoryRemoteNetworkException();
}

final class StoryRemoteTimeoutException extends StoryRemoteException {
  const StoryRemoteTimeoutException();
}

final class StoryRemoteServerException extends StoryRemoteException {
  const StoryRemoteServerException();
}

final class StoryRemoteMalformedResponseException
    extends StoryRemoteException {
  const StoryRemoteMalformedResponseException();
}

final class StoryRemoteUnknownException extends StoryRemoteException {
  const StoryRemoteUnknownException();
}
