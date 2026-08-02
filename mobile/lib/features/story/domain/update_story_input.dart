import 'package:memory_map/features/story/domain/story_update_field.dart';

final class UpdateStoryInput {
  factory UpdateStoryInput({
    required String storyId,
    StoryUpdateField<String> title =
        const StoryUpdateField<String>.notProvided(),
    StoryUpdateField<String> description =
        const StoryUpdateField<String>.notProvided(),
  }) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

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

    return UpdateStoryInput._(
      storyId: storyId,
      title: title,
      description: description,
    );
  }

  const UpdateStoryInput._({
    required this.storyId,
    required this.title,
    required this.description,
  });

  final String storyId;
  final StoryUpdateField<String> title;
  final StoryUpdateField<String> description;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UpdateStoryInput &&
            storyId == other.storyId &&
            title == other.title &&
            description == other.description;
  }

  @override
  int get hashCode => Object.hash(
        storyId,
        title,
        description,
      );

  @override
  String toString() => 'UpdateStoryInput';
}
