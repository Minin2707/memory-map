import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/story_summary_reconciler.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('StorySummaryReconciler', () {
    test('shouldSkipNetworkWhenNoLoadedStoryTargetsExist', () async {
      final repository = FakeStoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      await container
          .read(storySummaryReconcilerProvider)
          .reconcileAuthoritativeStory('story-1');

      expect(repository.getStoryCalls, 0);
      expect(repository.getStoriesCalls, 0);
    });

    test('shouldSkipNetworkWhenStoryResourceExistsButLoadFailed', () async {
      final repository = FakeStoryRepository()
        ..getStoriesFailure = const StoryApplicationException(
          StoryUnauthorized(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      await container
          .read(storySummaryReconcilerProvider)
          .reconcileAuthoritativeStory('story-1');

      expect(repository.getStoriesCalls, 1);
      expect(repository.getStoryCalls, 0);
    });

    test('shouldApplySingleAuthoritativeReadToLoadedStoriesAndDetails',
        () async {
      final oldPreview = storyPreviewPhoto(mediaId: 'media-old');
      final newPreview = storyPreviewPhoto(mediaId: 'media-new');
      final existing = userStory(previewPhoto: oldPreview);
      final authoritative = userStory(
        id: existing.story.id,
        title: 'Authoritative title',
        role: StoryRole.coOwner,
        memoryCount: 7,
        participantCount: 3,
        previewPhoto: newPreview,
      );
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[existing]
        ..storyResults.add(existing)
        ..storyResults.add(authoritative);
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      await container.read(storyDetailsProvider(existing.story.id).future);

      await container
          .read(storySummaryReconcilerProvider)
          .reconcileAuthoritativeStory(existing.story.id);

      expect(repository.getStoryCalls, 2);
      expect(repository.getStoriesCalls, 1);
      expect(
        container
            .read(storiesNotifierProvider)
            .asData!
            .value
            .stories
            .single,
        authoritative,
      );
      expect(
        container
            .read(storyDetailsProvider(existing.story.id))
            .asData!
            .value
            .userStory,
        authoritative,
      );
    });

    test('shouldClearPreviewFromLoadedTargetsWhenAuthoritativeReadIsNull',
        () async {
      final oldPreview = storyPreviewPhoto(mediaId: 'media-old');
      final existing = userStory(previewPhoto: oldPreview);
      final authoritative = userStory(id: existing.story.id);
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[existing]
        ..storyResults.add(existing)
        ..storyResults.add(authoritative);
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      await container.read(storyDetailsProvider(existing.story.id).future);

      await container
          .read(storySummaryReconcilerProvider)
          .reconcileAuthoritativeStory(existing.story.id);

      expect(
        container
            .read(storiesNotifierProvider)
            .asData!
            .value
            .stories
            .single
            .previewPhoto,
        isNull,
      );
      expect(
        container
            .read(storyDetailsProvider(existing.story.id))
            .asData!
            .value
            .userStory
            ?.previewPhoto,
        isNull,
      );
    });

    test('shouldNotFailWhenAuthoritativeRefreshFails', () async {
      final existing = userStory();
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[existing]
        ..getStoryFailure = const UnexpectedStoryException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      await container
          .read(storySummaryReconcilerProvider)
          .reconcileAuthoritativeStory(existing.story.id);

      expect(
        container.read(storiesNotifierProvider).asData!.value.stories,
        <UserStory>[existing],
      );
    });

    test('shouldRemoveStoryFromLoadedStoriesWithoutRefetch', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, coOwnerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storySummaryReconcilerProvider)
          .removeStory(ownerStory.story.id);

      expect(
        container.read(storiesNotifierProvider).asData!.value.stories,
        <UserStory>[coOwnerStory],
      );
      expect(repository.getStoryCalls, 0);
      expect(repository.getStoriesCalls, 1);
    });
  });
}

ProviderContainer createContainer(FakeStoryRepository repository) {
  return ProviderContainer(
    overrides: [
      storyRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

UserStory userStory({
  String id = 'story-1',
  String title = 'First story',
  StoryRole role = StoryRole.owner,
  int memoryCount = 0,
  int participantCount = 1,
  StoryPhotoPreview? previewPhoto,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: title,
      description: 'Description',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: role,
    memoryCount: memoryCount,
    participantCount: participantCount,
    previewPhoto: previewPhoto,
  );
}

StoryPhotoPreview storyPreviewPhoto({required String mediaId}) {
  return StoryPhotoPreview(
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
    displayPath: '/api/v1/media/$mediaId/display',
  );
}

final UserStory ownerStory = userStory();
final UserStory coOwnerStory = userStory(
  id: 'story-2',
  title: 'Second story',
  role: StoryRole.coOwner,
);

final class FakeStoryRepository implements StoryRepository {
  int getStoriesCalls = 0;
  int getStoryCalls = 0;

  List<UserStory> storiesResult = <UserStory>[];
  UserStory storyResult = ownerStory;
  final List<UserStory> storyResults = <UserStory>[];
  Object? getStoryFailure;
  Object? getStoriesFailure;

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    final failure = getStoriesFailure;
    if (failure != null) {
      throw failure;
    }

    return storiesResult;
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;

    final failure = getStoryFailure;
    if (failure != null) {
      throw failure;
    }

    if (storyResults.isNotEmpty) {
      return storyResults.removeAt(0);
    }

    return storyResult;
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> uploadStoryCover({
    required String storyId,
    required PreparedPhotoUpload photo,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> removeStoryCover({
    required String storyId,
  }) async {
    throw UnimplementedError();
  }
}

final class UnexpectedStoryException implements Exception {
  const UnexpectedStoryException();
}
