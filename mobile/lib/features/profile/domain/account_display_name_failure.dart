sealed class AccountDisplayNameFailure {
  const AccountDisplayNameFailure();
}

final class AccountDisplayNameValidationFailure
    extends AccountDisplayNameFailure {
  const AccountDisplayNameValidationFailure();
}

final class AccountDisplayNameUnauthorized extends AccountDisplayNameFailure {
  const AccountDisplayNameUnauthorized();
}

final class AccountDisplayNameNetworkUnavailable
    extends AccountDisplayNameFailure {
  const AccountDisplayNameNetworkUnavailable();
}

final class AccountDisplayNameRequestTimedOut
    extends AccountDisplayNameFailure {
  const AccountDisplayNameRequestTimedOut();
}

final class AccountDisplayNameServerFailure
    extends AccountDisplayNameFailure {
  const AccountDisplayNameServerFailure();
}

final class AccountDisplayNameLocalPersistenceFailure
    extends AccountDisplayNameFailure {
  const AccountDisplayNameLocalPersistenceFailure();
}

final class AccountDisplayNameUnknownFailure
    extends AccountDisplayNameFailure {
  const AccountDisplayNameUnknownFailure();
}
