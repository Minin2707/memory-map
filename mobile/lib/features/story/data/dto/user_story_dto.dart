import 'package:memory_map/features/story/data/dto/story_dto.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final class UserStoryDto {
  factory UserStoryDto.fromJson(Object? json) {
    final map = storyRequiredRootMap(json);

    return UserStoryDto(
      story: StoryDto.fromJson(map),
      role: storyRequiredRole(map, 'role'),
    );
  }

  const UserStoryDto({
    required this.story,
    required this.role,
  });

  final StoryDto story;
  final StoryRole role;

  UserStory toDomain() {
    return UserStory(
      story: story.toDomain(),
      role: role,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserStoryDto &&
            story == other.story &&
            role == other.role;
  }

  @override
  int get hashCode => Object.hash(
        story,
        role,
      );

  @override
  String toString() => 'UserStoryDto';
}

StoryRole storyRequiredRole(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed story response');
  }

  return switch (value) {
    'OWNER' => StoryRole.owner,
    'CO_OWNER' => StoryRole.coOwner,
    'EDITOR' => StoryRole.editor,
    'VIEWER' => StoryRole.viewer,
    _ => throw const FormatException('Malformed story response'),
  };
}
