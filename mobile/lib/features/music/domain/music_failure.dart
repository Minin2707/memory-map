sealed class MusicFailure {
  const MusicFailure();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MusicFailure && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class MusicValidationFailure extends MusicFailure {
  const MusicValidationFailure();
}

final class MusicUnauthorized extends MusicFailure {
  const MusicUnauthorized();
}

final class MusicUnavailable extends MusicFailure {
  const MusicUnavailable();
}

final class MusicNetworkUnavailable extends MusicFailure {
  const MusicNetworkUnavailable();
}

final class MusicRequestTimedOut extends MusicFailure {
  const MusicRequestTimedOut();
}

final class MusicServerFailure extends MusicFailure {
  const MusicServerFailure();
}

final class UnknownMusicFailure extends MusicFailure {
  const UnknownMusicFailure();
}
