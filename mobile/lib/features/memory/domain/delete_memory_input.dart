final class DeleteMemoryInput {
  factory DeleteMemoryInput({
    required String memoryId,
  }) {
    if (memoryId.trim().isEmpty) {
      throw ArgumentError('memoryId must not be blank');
    }

    return DeleteMemoryInput._(memoryId: memoryId);
  }

  const DeleteMemoryInput._({
    required this.memoryId,
  });

  final String memoryId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeleteMemoryInput && memoryId == other.memoryId;
  }

  @override
  int get hashCode => memoryId.hashCode;

  @override
  String toString() => 'DeleteMemoryInput';
}
