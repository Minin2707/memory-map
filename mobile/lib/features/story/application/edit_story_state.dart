import 'package:memory_map/features/story/domain/story_failure.dart';

final class EditStoryState {
  const EditStoryState({
    this.isSaving = false,
    this.saveFailure,
  });

  final bool isSaving;
  final StoryFailure? saveFailure;

  EditStoryState copyWith({
    bool? isSaving,
    StoryFailure? saveFailure,
    bool clearSaveFailure = false,
  }) {
    return EditStoryState(
      isSaving: isSaving ?? this.isSaving,
      saveFailure: clearSaveFailure ? null : saveFailure ?? this.saveFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EditStoryState &&
            isSaving == other.isSaving &&
            saveFailure == other.saveFailure;
  }

  @override
  int get hashCode => Object.hash(
        isSaving,
        saveFailure,
      );

  @override
  String toString() {
    return 'EditStoryState(isSaving: $isSaving, saveFailure: $saveFailure)';
  }
}
