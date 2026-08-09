import 'package:memory_map/features/memory/domain/memory_failure.dart';

final class DeleteMemoryState {
  const DeleteMemoryState({
    this.isDeleting = false,
    this.deleteFailure,
  });

  final bool isDeleting;
  final MemoryFailure? deleteFailure;

  bool get hasDeleteFailure => deleteFailure != null;

  DeleteMemoryState copyWith({
    bool? isDeleting,
    MemoryFailure? deleteFailure,
    bool clearDeleteFailure = false,
  }) {
    return DeleteMemoryState(
      isDeleting: isDeleting ?? this.isDeleting,
      deleteFailure:
          clearDeleteFailure ? null : deleteFailure ?? this.deleteFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeleteMemoryState &&
            isDeleting == other.isDeleting &&
            deleteFailure == other.deleteFailure;
  }

  @override
  int get hashCode => Object.hash(isDeleting, deleteFailure);

  @override
  String toString() {
    return 'DeleteMemoryState(isDeleting: $isDeleting, '
        'hasDeleteFailure: $hasDeleteFailure)';
  }
}
