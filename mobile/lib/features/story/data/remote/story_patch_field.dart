final class StoryPatchField<T> {
  const StoryPatchField.notProvided()
      : isProvided = false,
        value = null;

  const StoryPatchField.provided(this.value) : isProvided = true;

  final bool isProvided;
  final T? value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryPatchField<T> &&
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
      return 'StoryPatchField[provided]';
    }

    return 'StoryPatchField[notProvided]';
  }
}
