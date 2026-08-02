sealed class StoryFailure {
  const StoryFailure();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryFailure && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

final class StoryValidationFailure extends StoryFailure {
  const StoryValidationFailure();
}

final class StoryUnauthorized extends StoryFailure {
  const StoryUnauthorized();
}

final class StoryNotFound extends StoryFailure {
  const StoryNotFound();
}

final class StoryNetworkUnavailable extends StoryFailure {
  const StoryNetworkUnavailable();
}

final class StoryRequestTimedOut extends StoryFailure {
  const StoryRequestTimedOut();
}

final class StoryServerFailure extends StoryFailure {
  const StoryServerFailure();
}

final class UnknownStoryFailure extends StoryFailure {
  const UnknownStoryFailure();
}
