import 'package:memory_map/features/memory/domain/memory_failure.dart';

final class CreateMemoryState {
  const CreateMemoryState({
    this.isSubmitting = false,
    this.failure,
  });

  final bool isSubmitting;
  final MemoryFailure? failure;

  bool get hasFailure => failure != null;

  CreateMemoryState copyWith({
    bool? isSubmitting,
    MemoryFailure? failure,
    bool clearFailure = false,
  }) {
    return CreateMemoryState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CreateMemoryState &&
            isSubmitting == other.isSubmitting &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(isSubmitting, failure);

  @override
  String toString() {
    return 'CreateMemoryState(isSubmitting: $isSubmitting, '
        'hasFailure: $hasFailure)';
  }
}
