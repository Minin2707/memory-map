import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/story_cover_notifier.dart';
import 'package:memory_map/features/story/application/story_cover_state.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('StoryCoverNotifier upload', () {
    test('shouldUploadPreparedPhotoAndApplyAuthoritativeCoverPreview',
        () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[
          userStory(previewPhoto: automaticPreview),
        ]
        ..storyResult = userStory(previewPhoto: automaticPreview)
        ..uploadCoverResult = userStory(previewPhoto: explicitCoverPreview);
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadStoryState(container);
      final subscription = keepStoryCoverAlive(container);
      addTearDown(subscription.close);
      await container.read(storyCoverProvider(defaultStoryId).future);
      final photo = preparedPhotoUpload();

      final result = await container
          .read(storyCoverProvider(defaultStoryId).notifier)
          .uploadStoryCover(photo);

      expect(result, repository.uploadCoverResult);
      expect(repository.uploadCoverCalls, 1);
      expect(repository.receivedUploadCoverStoryId, defaultStoryId);
      expect(repository.receivedUploadCoverPhoto, photo);
      expect(
        readStories(container).stories.single.previewPhoto,
        explicitCoverPreview,
      );
      expect(
        readDetails(container).userStory?.previewPhoto,
        explicitCoverPreview,
      );
      expect(
        container.read(storyCoverProvider(defaultStoryId)).asData!.value,
        const StoryCoverState(),
      );
    });

    test('shouldIgnoreDuplicateUploadsWhilePending', () async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()
        ..uploadCoverCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final subscription = keepStoryCoverAlive(container);
      addTearDown(subscription.close);
      await container.read(storyCoverProvider(defaultStoryId).future);
      final notifier = container.read(storyCoverProvider(defaultStoryId)
          .notifier);

      final firstUpload = notifier.uploadStoryCover(preparedPhotoUpload());
      await pumpEventQueue();
      final duplicateResult = await notifier.uploadStoryCover(
        preparedPhotoUpload(bytes: <int>[7]),
      );

      expect(duplicateResult, isNull);
      expect(repository.uploadCoverCalls, 1);
      expect(
        container
            .read(storyCoverProvider(defaultStoryId))
            .asData!
            .value
            .isUploading,
        isTrue,
      );

      completer.complete(repository.uploadCoverResult);
      await firstUpload;
    });

    test('shouldExposeKnownUploadFailureWithoutReconciliation', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[
          userStory(previewPhoto: automaticPreview),
        ]
        ..uploadCoverFailure = const StoryApplicationException(
          StoryValidationFailure(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      final subscription = keepStoryCoverAlive(container);
      addTearDown(subscription.close);
      await container.read(storyCoverProvider(defaultStoryId).future);

      final result = await container
          .read(storyCoverProvider(defaultStoryId).notifier)
          .uploadStoryCover(preparedPhotoUpload());

      expect(result, isNull);
      expect(readStories(container).stories.single.previewPhoto, automaticPreview);
      expect(
        container.read(storyCoverProvider(defaultStoryId)).asData!.value,
        const StoryCoverState(failure: StoryValidationFailure()),
      );
    });

    test('shouldIgnoreCompletedUploadAfterProviderInvalidation', () async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[
          userStory(previewPhoto: automaticPreview),
        ]
        ..storyResult = userStory(previewPhoto: automaticPreview)
        ..uploadCoverCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadStoryState(container);
      final provider = storyCoverProvider(defaultStoryId);
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(provider.future);

      final upload = container
          .read(provider.notifier)
          .uploadStoryCover(preparedPhotoUpload());
      await pumpEventQueue();
      container.invalidate(provider);
      await pumpEventQueue();

      completer.complete(userStory(previewPhoto: explicitCoverPreview));

      expect(await upload, isNull);
      expect(readStories(container).stories.single.previewPhoto, automaticPreview);
      expect(readDetails(container).userStory?.previewPhoto, automaticPreview);
    });
  });

  group('StoryCoverNotifier remove', () {
    test('shouldApplyAuthoritativeAutomaticFallbackPreview', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[
          userStory(previewPhoto: explicitCoverPreview),
        ]
        ..storyResult = userStory(previewPhoto: explicitCoverPreview)
        ..removeCoverResult = userStory(previewPhoto: automaticPreview);
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadStoryState(container);
      final subscription = keepStoryCoverAlive(container);
      addTearDown(subscription.close);
      await container.read(storyCoverProvider(defaultStoryId).future);

      final result = await container
          .read(storyCoverProvider(defaultStoryId).notifier)
          .removeStoryCover();

      expect(result, repository.removeCoverResult);
      expect(repository.removeCoverCalls, 1);
      expect(repository.receivedRemoveCoverStoryId, defaultStoryId);
      expect(readStories(container).stories.single.previewPhoto, automaticPreview);
      expect(readDetails(container).userStory?.previewPhoto, automaticPreview);
    });

    test('shouldApplyAuthoritativeNullPreview', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[
          userStory(previewPhoto: explicitCoverPreview),
        ]
        ..storyResult = userStory(previewPhoto: explicitCoverPreview)
        ..removeCoverResult = userStory();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadStoryState(container);
      final subscription = keepStoryCoverAlive(container);
      addTearDown(subscription.close);
      await container.read(storyCoverProvider(defaultStoryId).future);

      await container
          .read(storyCoverProvider(defaultStoryId).notifier)
          .removeStoryCover();

      expect(readStories(container).stories.single.previewPhoto, isNull);
      expect(readDetails(container).userStory?.previewPhoto, isNull);
    });

    test('shouldIgnoreCompletedRemoveAfterProviderInvalidation', () async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[
          userStory(previewPhoto: explicitCoverPreview),
        ]
        ..storyResult = userStory(previewPhoto: explicitCoverPreview)
        ..removeCoverCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await loadStoryState(container);
      final provider = storyCoverProvider(defaultStoryId);
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(provider.future);

      final remove = container.read(provider.notifier).removeStoryCover();
      await pumpEventQueue();
      container.invalidate(provider);
      await pumpEventQueue();

      completer.complete(userStory(previewPhoto: automaticPreview));

      expect(await remove, isNull);
      expect(
        readStories(container).stories.single.previewPhoto,
        explicitCoverPreview,
      );
      expect(readDetails(container).userStory?.previewPhoto, explicitCoverPreview);
    });
  });

  group('StoryCoverNotifier validation', () {
    test('shouldRejectBlankStoryIdWithoutRepositoryCall', () async {
      final repository = FakeStoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final provider = storyCoverProvider('   ');
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(provider.future);

      final result = await container.read(provider.notifier)
          .uploadStoryCover(preparedPhotoUpload());

      expect(result, isNull);
      expect(repository.uploadCoverCalls, 0);
      expect(
        container.read(provider).asData!.value.failure,
        const StoryValidationFailure(),
      );
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

ProviderSubscription<AsyncValue<StoryCoverState>> keepStoryCoverAlive(
  ProviderContainer container,
) {
  return container.listen(
    storyCoverProvider(defaultStoryId),
    (_, __) {},
    fireImmediately: true,
  );
}

Future<void> loadStoryState(ProviderContainer container) async {
  await container.read(storiesNotifierProvider.future);
  await container.read(storyDetailsProvider(defaultStoryId).future);
}

dynamic readStories(ProviderContainer container) {
  return container.read(storiesNotifierProvider).asData!.value;
}

dynamic readDetails(ProviderContainer container) {
  return container.read(storyDetailsProvider(defaultStoryId)).asData!.value;
}

PreparedPhotoUpload preparedPhotoUpload({List<int> bytes = const <int>[1]}) {
  return PreparedPhotoUpload(
    bytes: Uint8List.fromList(bytes),
    contentType: 'image/jpeg',
  );
}

UserStory userStory({
  String id = defaultStoryId,
  StoryPhotoPreview? previewPhoto,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: 'Our Story',
      description: 'The beginning',
      createdAt: DateTime.utc(2026, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: StoryRole.owner,
    memoryCount: 2,
    participantCount: 1,
    previewPhoto: previewPhoto,
  );
}

const String defaultStoryId = 'story-1';

final StoryPhotoPreview automaticPreview = StoryPhotoPreview(
  thumbnailPath: '/api/v1/media/media-id/thumbnail',
  displayPath: '/api/v1/media/media-id/display',
);

final StoryPhotoPreview explicitCoverPreview = StoryPhotoPreview(
  thumbnailPath: '/api/v1/stories/story-1/cover/thumbnail/111',
  displayPath: '/api/v1/stories/story-1/cover/display/111',
);

final class FakeStoryRepository implements StoryRepository {
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int uploadCoverCalls = 0;
  int removeCoverCalls = 0;
  String? receivedUploadCoverStoryId;
  PreparedPhotoUpload? receivedUploadCoverPhoto;
  String? receivedRemoveCoverStoryId;
  List<UserStory> storiesResult = <UserStory>[userStory()];
  UserStory storyResult = userStory();
  UserStory uploadCoverResult = userStory(previewPhoto: explicitCoverPreview);
  UserStory removeCoverResult = userStory(previewPhoto: automaticPreview);
  Object? uploadCoverFailure;
  Object? removeCoverFailure;
  Completer<UserStory>? uploadCoverCompleter;
  Completer<UserStory>? removeCoverCompleter;

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
    return storiesResult;
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
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
    uploadCoverCalls += 1;
    receivedUploadCoverStoryId = storyId;
    receivedUploadCoverPhoto = photo;

    final completer = uploadCoverCompleter;
    if (completer != null) {
      uploadCoverCompleter = null;
      return completer.future;
    }

    final failure = uploadCoverFailure;
    if (failure != null) {
      throw failure;
    }

    return uploadCoverResult;
  }

  @override
  Future<UserStory> removeStoryCover({
    required String storyId,
  }) async {
    removeCoverCalls += 1;
    receivedRemoveCoverStoryId = storyId;

    final completer = removeCoverCompleter;
    if (completer != null) {
      removeCoverCompleter = null;
      return completer.future;
    }

    final failure = removeCoverFailure;
    if (failure != null) {
      throw failure;
    }

    return removeCoverResult;
  }
}
