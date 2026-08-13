import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

final class UserStory {
  factory UserStory({
    required Story story,
    required StoryRole role,
    int memoryCount = 0,
    int participantCount = 1,
    StoryPhotoPreview? previewPhoto,
  }) {
    if (memoryCount < 0) {
      throw ArgumentError('memoryCount must not be negative');
    }

    if (participantCount < 1) {
      throw ArgumentError('participantCount must be positive');
    }

    return UserStory._(
      story: story,
      role: role,
      memoryCount: memoryCount,
      participantCount: participantCount,
      previewPhoto: previewPhoto,
    );
  }

  const UserStory._({
    required this.story,
    required this.role,
    required this.memoryCount,
    required this.participantCount,
    required this.previewPhoto,
  });

  final Story story;
  final StoryRole role;
  final int memoryCount;
  final int participantCount;
  final StoryPhotoPreview? previewPhoto;

  bool get canUpdateStoryMetadata => role.canUpdateStoryMetadata;

  bool get hasPreviewPhoto => previewPhoto != null;

  UserStory withStoryMutation(Story updatedStory) {
    if (updatedStory.id != story.id) {
      throw ArgumentError('updatedStory id must match story id');
    }

    return UserStory(
      story: updatedStory,
      role: role,
      memoryCount: memoryCount,
      participantCount: participantCount,
      previewPhoto: previewPhoto,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserStory &&
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
  String toString() {
    return 'UserStory(role: $role, memoryCount: $memoryCount, '
        'participantCount: $participantCount, '
        'hasPreviewPhoto: $hasPreviewPhoto)';
  }
}
