sealed class MediaFailure {
  const MediaFailure();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MediaFailure && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class MediaValidationFailure extends MediaFailure {
  const MediaValidationFailure();
}

final class MediaUnauthorized extends MediaFailure {
  const MediaUnauthorized();
}

final class MediaUnavailable extends MediaFailure {
  const MediaUnavailable();
}

final class MediaUploadUnavailable extends MediaFailure {
  const MediaUploadUnavailable();
}

final class MediaNetworkUnavailable extends MediaFailure {
  const MediaNetworkUnavailable();
}

final class MediaRequestTimedOut extends MediaFailure {
  const MediaRequestTimedOut();
}

final class MediaServerFailure extends MediaFailure {
  const MediaServerFailure();
}

final class MediaPreprocessingFailure extends MediaFailure {
  const MediaPreprocessingFailure();
}

final class UnknownMediaFailure extends MediaFailure {
  const UnknownMediaFailure();
}
