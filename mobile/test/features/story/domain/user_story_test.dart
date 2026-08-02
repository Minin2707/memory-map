import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story.dart';
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
      );
      final second = UserStory(
        story: createStory(),
        role: StoryRole.owner,
      );
      final different = UserStory(
        story: createStory(),
        role: StoryRole.viewer,
      );

      expect(first, second);
      expect(first, isNot(different));
    });

    test('shouldProduceStableHashCode', () {
      final first = UserStory(
        story: createStory(),
        role: StoryRole.owner,
      );
      final second = UserStory(
        story: createStory(),
        role: StoryRole.owner,
      );

      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeOnlyStoryAndRoleInToString', () {
      final userStory = UserStory(
        story: createStory(),
        role: StoryRole.owner,
      );

      expect(
        userStory.toString(),
        'UserStory(story: Story(id: story-id, title: Our Story, '
        'description: Together since 2021, '
        'createdAt: 2026-07-31 10:00:00.000Z, '
        'updatedAt: 2026-07-31 11:00:00.000Z), role: StoryRole.owner)',
      );
      expect(userStory.toString(), isNot(contains('ownerId')));
      expect(userStory.toString(), isNot(contains('userId')));
      expect(userStory.toString(), isNot(contains('token')));
    });
  });
}

Story createStory() {
  return Story(
    id: 'story-id',
    title: 'Our Story',
    description: 'Together since 2021',
    createdAt: DateTime.utc(2026, 7, 31, 10),
    updatedAt: DateTime.utc(2026, 7, 31, 11),
  );
}
