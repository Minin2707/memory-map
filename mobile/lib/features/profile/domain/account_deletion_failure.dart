sealed class AccountDeletionFailure {
  const AccountDeletionFailure();
}

final class AccountDeletionOwnershipConflict extends AccountDeletionFailure {
  const AccountDeletionOwnershipConflict();
}

final class AccountDeletionUnauthorized extends AccountDeletionFailure {
  const AccountDeletionUnauthorized();
}

final class AccountDeletionNetworkUnavailable extends AccountDeletionFailure {
  const AccountDeletionNetworkUnavailable();
}

final class AccountDeletionRequestTimedOut extends AccountDeletionFailure {
  const AccountDeletionRequestTimedOut();
}

final class AccountDeletionServerFailure extends AccountDeletionFailure {
  const AccountDeletionServerFailure();
}

final class AccountDeletionUnknownFailure extends AccountDeletionFailure {
  const AccountDeletionUnknownFailure();
}
