import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('UserStory', () {
    test('shouldCreateUserStory', () {
      final story = createStory();

      final userStory = UserStory(
        story: story,
        role: StoryRole.owner,
      );

      expect(userStory.story, story);
      expect(userStory.role, StoryRole.owner);
      expect(userStory.memoryCount, 0);
      expect(userStory.participantCount, 1);
      expect(userStory.previewPhoto, isNull);
    });

    test('shouldCreateUserStoryWithProjectionMetadata', () {
      final preview = storyPreviewPhoto(mediaId: 'media-a');

      final userStory = UserStory(
        story: createStory(),
        role: StoryRole.coOwner,
        memoryCount: 12,
        participantCount: 3,
        previewPhoto: preview,
      );

      expect(userStory.memoryCount, 12);
      expect(userStory.participantCount, 3);
      expect(userStory.previewPhoto, preview);
      expect(userStory.hasPreviewPhoto, isTrue);
    });

    test('shouldRejectInvalidProjectionCounts', () {
      expect(
        () => UserStory(
          story: createStory(),
          role: StoryRole.owner,
          memoryCount: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => UserStory(
          story: createStory(),
          role: StoryRole.owner,
          participantCount: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldExposeMetadataUpdateCapabilityFromRole', () {
      expect(
        UserStory(story: createStory(), role: StoryRole.owner)
            .canUpdateStoryMetadata,
        isTrue,
      );
      expect(
        UserStory(story: createStory(), role: StoryRole.coOwner)
            .canUpdateStoryMetadata,
        isTrue,
      );
      expect(
        UserStory(story: createStory(), role: StoryRole.editor)
            .canUpdateStoryMetadata,
        isFalse,
      );
      expect(
        UserStory(story: createStory(), role: StoryRole.viewer)
            .canUpdateStoryMetadata,
        isFalse,
      );
    });

    test('shouldCompareUserStoriesByValue', () {
      final first = UserStory(
        story: createStory(),
        role: StoryRole.owner,
        memoryCount: 2,
        participantCount: 3,
        previewPhoto: storyPreviewPhoto(mediaId: 'media-a'),
      );
      final second = UserStory(
        story: createStory(),
        role: StoryRole.owner,
        memoryCount: 2,
        participantCount: 3,
        previewPhoto: storyPreviewPhoto(mediaId: 'media-a'),
      );
      final different = UserStory(
        story: createStory(),
        role: StoryRole.viewer,
        memoryCount: 2,
        participantCount: 3,
        previewPhoto: storyPreviewPhoto(mediaId: 'media-a'),
      );

      expect(first, second);
      expect(first, isNot(different));
    });

    test('shouldProduceStableHashCode', () {
      final first = UserStory(
        story: createStory(),
        role: StoryRole.owner,
        memoryCount: 2,
        participantCount: 3,
      );
      final second = UserStory(
        story: createStory(),
        role: StoryRole.owner,
        memoryCount: 2,
        participantCount: 3,
      );

      expect(first.hashCode, second.hashCode);
    });

    test('shouldPreserveProjectionMetadataForStoryMutation', () {
      final userStory = UserStory(
        story: createStory(),
        role: StoryRole.owner,
        memoryCount: 12,
        participantCount: 2,
        previewPhoto: storyPreviewPhoto(mediaId: 'media-a'),
      );

      final updated = createStory(title: 'Updated Story');

      final result = userStory.withStoryMutation(updated);

      expect(result.story, updated);
      expect(result.role, userStory.role);
      expect(result.memoryCount, 12);
      expect(result.participantCount, 2);
      expect(result.previewPhoto, userStory.previewPhoto);
    });

    test('shouldRejectStoryMutationWithDifferentId', () {
      final userStory = UserStory(
        story: createStory(),
        role: StoryRole.owner,
      );

      expect(
        () => userStory.withStoryMutation(createStory(id: 'other-story')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldExposeSafeToString', () {
      final userStory = UserStory(
        story: createStory(),
        role: StoryRole.owner,
        memoryCount: 4,
        participantCount: 2,
        previewPhoto: storyPreviewPhoto(mediaId: 'media-a'),
      );

      expect(
        userStory.toString(),
        'UserStory(role: StoryRole.owner, memoryCount: 4, '
        'participantCount: 2, hasPreviewPhoto: true)',
      );
      expect(userStory.toString(), isNot(contains('story-id')));
      expect(userStory.toString(), isNot(contains('Our Story')));
      expect(userStory.toString(), isNot(contains('Together since 2021')));
      expect(userStory.toString(), isNot(contains('media-a')));
      expect(userStory.toString(), isNot(contains('/api/v1/media')));
      expect(userStory.toString(), isNot(contains('ownerId')));
      expect(userStory.toString(), isNot(contains('userId')));
      expect(userStory.toString(), isNot(contains('token')));
    });
  });
}

Story createStory({
  String id = 'story-id',
  String title = 'Our Story',
}) {
  return story(id: id, title: title);
}

Story story({
  String id = 'story-id',
  String title = 'Our Story',
}) {
  return Story(
    id: id,
    title: title,
    description: 'Together since 2021',
    createdAt: DateTime.utc(2026, 7, 31, 10),
    updatedAt: DateTime.utc(2026, 7, 31, 11),
  );
}

StoryPhotoPreview storyPreviewPhoto({required String mediaId}) {
  return StoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}
