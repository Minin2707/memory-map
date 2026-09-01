sealed class NotificationFailure {
  const NotificationFailure();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotificationFailure && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class NotificationValidationFailure extends NotificationFailure {
  const NotificationValidationFailure();
}

final class NotificationUnauthorized extends NotificationFailure {
  const NotificationUnauthorized();
}

final class NotificationNotFound extends NotificationFailure {
  const NotificationNotFound();
}

final class NotificationNetworkUnavailable extends NotificationFailure {
  const NotificationNetworkUnavailable();
}

final class NotificationRequestTimedOut extends NotificationFailure {
  const NotificationRequestTimedOut();
}

final class NotificationServerFailure extends NotificationFailure {
  const NotificationServerFailure();
}

final class UnknownNotificationFailure extends NotificationFailure {
  const UnknownNotificationFailure();
}
