final class MemoryPatchField<T> {
  const MemoryPatchField.notProvided()
      : isProvided = false,
        value = null;

  const MemoryPatchField.provided(this.value) : isProvided = true;

  final bool isProvided;
  final T? value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryPatchField<T> &&
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
      return 'MemoryPatchField[provided]';
    }

    return 'MemoryPatchField[notProvided]';
  }
}
