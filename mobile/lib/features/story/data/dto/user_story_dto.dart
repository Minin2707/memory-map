import 'package:memory_map/features/story/data/dto/story_dto.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final class UserStoryDto {
  factory UserStoryDto.fromJson(Object? json) {
    final map = storyRequiredRootMap(json);

    return UserStoryDto(
      story: StoryDto.fromJson(map),
      role: storyRequiredRole(map, 'role'),
      memoryCount: storyRequiredNonNegativeInt(map, 'memoryCount'),
      participantCount: storyRequiredPositiveInt(map, 'participantCount'),
      previewPhoto: StoryPhotoPreviewDto.fromNullableJson(
        map['previewPhoto'],
      ),
    );
  }

  const UserStoryDto({
    required this.story,
    required this.role,
    required this.memoryCount,
    required this.participantCount,
    this.previewPhoto,
  });

  final StoryDto story;
  final StoryRole role;
  final int memoryCount;
  final int participantCount;
  final StoryPhotoPreviewDto? previewPhoto;

  UserStory toDomain() {
    return UserStory(
      story: story.toDomain(),
      role: role,
      memoryCount: memoryCount,
      participantCount: participantCount,
      previewPhoto: previewPhoto?.toDomain(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserStoryDto &&
            story == other.story &&
            role == other.role &&
            memoryCount == other.memoryCount &&
            participantCount == other.participantCount &&
            previewPhoto == other.previewPhoto;
  }

  @override
  int get hashCode => Object.hash(
        story,
        role,
        memoryCount,
        participantCount,
        previewPhoto,
      );

  @override
  String toString() => 'UserStoryDto';
}

final class StoryPhotoPreviewDto {
  factory StoryPhotoPreviewDto.fromJson(Object? json) {
    final map = storyRequiredRootMap(json);

    return StoryPhotoPreviewDto(
      thumbnailPath: storyRequiredString(map, 'thumbnailUrl'),
      displayPath: storyRequiredString(map, 'displayUrl'),
    );
  }

  static StoryPhotoPreviewDto? fromNullableJson(Object? json) {
    if (json == null) {
      return null;
    }

    return StoryPhotoPreviewDto.fromJson(json);
  }

  StoryPhotoPreviewDto({
    required this.thumbnailPath,
    required this.displayPath,
  }) {
    try {
      StoryPhotoPreview(
        thumbnailPath: thumbnailPath,
        displayPath: displayPath,
      );
    } on Object {
      throw const FormatException('Malformed story response');
    }
  }

  final String thumbnailPath;
  final String displayPath;

  StoryPhotoPreview toDomain() {
    return StoryPhotoPreview(
      thumbnailPath: thumbnailPath,
      displayPath: displayPath,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryPhotoPreviewDto &&
            thumbnailPath == other.thumbnailPath &&
            displayPath == other.displayPath;
  }

  @override
  int get hashCode => Object.hash(thumbnailPath, displayPath);

  @override
  String toString() => 'StoryPhotoPreviewDto';
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

int storyRequiredNonNegativeInt(Map<Object?, Object?> json, String key) {
  final value = storyRequiredInt(json, key);
  if (value < 0) {
    throw const FormatException('Malformed story response');
  }

  return value;
}

int storyRequiredPositiveInt(Map<Object?, Object?> json, String key) {
  final value = storyRequiredInt(json, key);
  if (value < 1) {
    throw const FormatException('Malformed story response');
  }

  return value;
}

int storyRequiredInt(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw const FormatException('Malformed story response');
  }

  return value;
}
