final class MemoryUpdateField<T> {
  const MemoryUpdateField.notProvided()
      : isProvided = false,
        value = null;

  const MemoryUpdateField.provided(this.value) : isProvided = true;

  final bool isProvided;
  final T? value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryUpdateField<T> &&
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
      return 'MemoryUpdateField[provided]';
    }

    return 'MemoryUpdateField[notProvided]';
  }
}
