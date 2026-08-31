import 'package:memory_map/features/story/domain/story_failure.dart';

final class StoryCoverState {
  const StoryCoverState({
    this.isUploading = false,
    this.isRemoving = false,
    this.failure,
  });

  final bool isUploading;
  final bool isRemoving;
  final StoryFailure? failure;

  bool get isBusy => isUploading || isRemoving;

  StoryCoverState copyWith({
    bool? isUploading,
    bool? isRemoving,
    StoryFailure? failure,
    bool clearFailure = false,
  }) {
    return StoryCoverState(
      isUploading: isUploading ?? this.isUploading,
      isRemoving: isRemoving ?? this.isRemoving,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryCoverState &&
            isUploading == other.isUploading &&
            isRemoving == other.isRemoving &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        isUploading,
        isRemoving,
        failure,
      );

  @override
  String toString() {
    return 'StoryCoverState(isUploading: $isUploading, '
        'isRemoving: $isRemoving, failure: $failure)';
  }
}
