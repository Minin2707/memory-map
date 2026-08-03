sealed class InviteFailure {
  const InviteFailure();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InviteFailure && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class InviteValidationFailure extends InviteFailure {
  const InviteValidationFailure();
}

final class InviteUnauthorized extends InviteFailure {
  const InviteUnauthorized();
}

final class InviteNotFound extends InviteFailure {
  const InviteNotFound();
}

final class InviteNetworkUnavailable extends InviteFailure {
  const InviteNetworkUnavailable();
}

final class InviteRequestTimedOut extends InviteFailure {
  const InviteRequestTimedOut();
}

final class InviteServerFailure extends InviteFailure {
  const InviteServerFailure();
}

final class UnknownInviteFailure extends InviteFailure {
  const UnknownInviteFailure();
}
