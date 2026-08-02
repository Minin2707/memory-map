final class StoryUpdateField<T> {
  const StoryUpdateField.notProvided()
      : isProvided = false,
        value = null;

  const StoryUpdateField.provided(this.value) : isProvided = true;

  final bool isProvided;
  final T? value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryUpdateField<T> &&
            isProvided == other.isProvided &&
            value == other.value;
  }

  @override
  int get hashCode => Object.hash(
        isProvided,
        value,
      );

  @override
  String toString() {
    if (isProvided) {
      return 'StoryUpdateField[provided]';
    }

    return 'StoryUpdateField[notProvided]';
  }
}
