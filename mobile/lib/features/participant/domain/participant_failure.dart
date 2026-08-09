sealed class ParticipantFailure {
  const ParticipantFailure();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ParticipantFailure && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class ParticipantValidationFailure extends ParticipantFailure {
  const ParticipantValidationFailure();
}

final class ParticipantUnauthorized extends ParticipantFailure {
  const ParticipantUnauthorized();
}

final class ParticipantNotFound extends ParticipantFailure {
  const ParticipantNotFound();
}

final class ParticipantLastOwnerConflict extends ParticipantFailure {
  const ParticipantLastOwnerConflict();
}

final class ParticipantCannotRemoveSelf extends ParticipantFailure {
  const ParticipantCannotRemoveSelf();
}

final class ParticipantOwnerCannotBeRemoved extends ParticipantFailure {
  const ParticipantOwnerCannotBeRemoved();
}

final class ParticipantNetworkUnavailable extends ParticipantFailure {
  const ParticipantNetworkUnavailable();
}

final class ParticipantRequestTimedOut extends ParticipantFailure {
  const ParticipantRequestTimedOut();
}

final class ParticipantServerFailure extends ParticipantFailure {
  const ParticipantServerFailure();
}

final class UnknownParticipantFailure extends ParticipantFailure {
  const UnknownParticipantFailure();
}
