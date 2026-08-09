sealed class ParticipantRemoteException implements Exception {
  const ParticipantRemoteException();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ParticipantRemoteException &&
            other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class ParticipantRemoteValidationException
    extends ParticipantRemoteException {
  const ParticipantRemoteValidationException();
}

final class ParticipantRemoteUnauthorizedException
    extends ParticipantRemoteException {
  const ParticipantRemoteUnauthorizedException();
}

final class ParticipantRemoteNotFoundException
    extends ParticipantRemoteException {
  const ParticipantRemoteNotFoundException();
}

final class ParticipantRemoteLastOwnerConflictException
    extends ParticipantRemoteException {
  const ParticipantRemoteLastOwnerConflictException();
}

final class ParticipantRemoteCannotRemoveSelfException
    extends ParticipantRemoteException {
  const ParticipantRemoteCannotRemoveSelfException();
}

final class ParticipantRemoteOwnerCannotBeRemovedException
    extends ParticipantRemoteException {
  const ParticipantRemoteOwnerCannotBeRemovedException();
}

final class ParticipantRemoteNetworkException
    extends ParticipantRemoteException {
  const ParticipantRemoteNetworkException();
}

final class ParticipantRemoteTimeoutException
    extends ParticipantRemoteException {
  const ParticipantRemoteTimeoutException();
}

final class ParticipantRemoteServerException
    extends ParticipantRemoteException {
  const ParticipantRemoteServerException();
}

final class ParticipantRemoteMalformedResponseException
    extends ParticipantRemoteException {
  const ParticipantRemoteMalformedResponseException();
}

final class ParticipantRemoteUnknownException
    extends ParticipantRemoteException {
  const ParticipantRemoteUnknownException();
}
