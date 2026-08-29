sealed class AccountAvatarFailure {
  const AccountAvatarFailure();
}

final class AccountAvatarCancelled extends AccountAvatarFailure {
  const AccountAvatarCancelled();
}

final class AccountAvatarValidationFailure extends AccountAvatarFailure {
  const AccountAvatarValidationFailure();
}

final class AccountAvatarUnauthorized extends AccountAvatarFailure {
  const AccountAvatarUnauthorized();
}

final class AccountAvatarNetworkUnavailable extends AccountAvatarFailure {
  const AccountAvatarNetworkUnavailable();
}

final class AccountAvatarRequestTimedOut extends AccountAvatarFailure {
  const AccountAvatarRequestTimedOut();
}

final class AccountAvatarServerFailure extends AccountAvatarFailure {
  const AccountAvatarServerFailure();
}

final class AccountAvatarLocalPersistenceFailure extends AccountAvatarFailure {
  const AccountAvatarLocalPersistenceFailure();
}

final class AccountAvatarUnknownFailure extends AccountAvatarFailure {
  const AccountAvatarUnknownFailure();
}
