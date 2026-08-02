import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

final class UserStory {
  const UserStory({
    required this.story,
    required this.role,
  });

  final Story story;
  final StoryRole role;

  bool get canUpdateStoryMetadata => role.canUpdateStoryMetadata;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserStory && story == other.story && role == other.role;
  }

  @override
  int get hashCode => Object.hash(
        story,
        role,
      );

  @override
  String toString() => 'UserStory(story: $story, role: $role)';
}
