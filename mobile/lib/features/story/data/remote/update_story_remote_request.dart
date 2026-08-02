import 'package:memory_map/features/story/data/remote/story_patch_field.dart';

final class UpdateStoryRemoteRequest {
  factory UpdateStoryRemoteRequest({
    StoryPatchField<String> title =
        const StoryPatchField<String>.notProvided(),
    StoryPatchField<String> description =
        const StoryPatchField<String>.notProvided(),
  }) {
    if (!title.isProvided && !description.isProvided) {
      throw ArgumentError('at least one update field must be provided');
    }

    if (title.isProvided) {
      final titleValue = title.value;
      if (titleValue == null) {
        throw ArgumentError('title must not be null');
      }

      if (titleValue.trim().isEmpty) {
        throw ArgumentError('title must not be blank');
      }
    }

    return UpdateStoryRemoteRequest._(
      title: title,
      description: description,
    );
  }

  const UpdateStoryRemoteRequest._({
    required this.title,
    required this.description,
  });

  final StoryPatchField<String> title;
  final StoryPatchField<String> description;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (title.isProvided) 'title': title.value,
      if (description.isProvided) 'description': description.value,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UpdateStoryRemoteRequest &&
            title == other.title &&
            description == other.description;
  }

  @override
  int get hashCode => Object.hash(
        title,
        description,
      );

  @override
  String toString() => 'UpdateStoryRemoteRequest';
}
