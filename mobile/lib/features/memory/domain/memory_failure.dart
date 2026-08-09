sealed class MemoryFailure {
  const MemoryFailure();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryFailure && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class MemoryValidationFailure extends MemoryFailure {
  const MemoryValidationFailure();
}

final class MemoryUnauthorized extends MemoryFailure {
  const MemoryUnauthorized();
}

final class MemoryStoryUnavailable extends MemoryFailure {
  const MemoryStoryUnavailable();
}

final class MemoryNotFound extends MemoryFailure {
  const MemoryNotFound();
}

final class MemoryCreationUnavailable extends MemoryFailure {
  const MemoryCreationUnavailable();
}

final class MemoryUpdateUnavailable extends MemoryFailure {
  const MemoryUpdateUnavailable();
}

final class MemoryDeletionUnavailable extends MemoryFailure {
  const MemoryDeletionUnavailable();
}

final class MemoryNetworkUnavailable extends MemoryFailure {
  const MemoryNetworkUnavailable();
}

final class MemoryRequestTimedOut extends MemoryFailure {
  const MemoryRequestTimedOut();
}

final class MemoryServerFailure extends MemoryFailure {
  const MemoryServerFailure();
}

final class UnknownMemoryFailure extends MemoryFailure {
  const UnknownMemoryFailure();
}
