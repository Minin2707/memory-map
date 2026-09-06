import 'package:memory_map/features/story/domain/story_failure.dart';

final class DeleteStoryState {
  const DeleteStoryState({
    this.isDeleting = false,
    this.deleteFailure,
  });

  final bool isDeleting;
  final StoryFailure? deleteFailure;

  bool get hasDeleteFailure => deleteFailure != null;

  DeleteStoryState copyWith({
    bool? isDeleting,
    StoryFailure? deleteFailure,
    bool clearDeleteFailure = false,
  }) {
    return DeleteStoryState(
      isDeleting: isDeleting ?? this.isDeleting,
      deleteFailure:
          clearDeleteFailure ? null : deleteFailure ?? this.deleteFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeleteStoryState &&
            isDeleting == other.isDeleting &&
            deleteFailure == other.deleteFailure;
  }

  @override
  int get hashCode => Object.hash(isDeleting, deleteFailure);

  @override
  String toString() {
    return 'DeleteStoryState(isDeleting: $isDeleting, '
        'hasDeleteFailure: $hasDeleteFailure)';
  }
}
