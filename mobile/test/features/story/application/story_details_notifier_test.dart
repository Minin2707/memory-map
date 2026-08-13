import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/application/story_details_state.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('StoryDetailsNotifier startup', () {
    test('shouldStartWithAsyncLoading', () async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()..getStoryCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final future = container.read(storyDetailsProvider('story-1').future);

      expect(
        container.read(storyDetailsProvider('story-1')),
        isA<AsyncLoading<StoryDetailsState>>(),
      );

      completer.complete(ownerStory);
      await future;
    });

    test('shouldLoadExactUserStoryFromRepository', () async {
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(storyDetailsProvider('story-1').future);

      expect(state.userStory, ownerStory);
      expect(repository.receivedStoryId, 'story-1');
      expect(repository.getStoryCalls, 1);
    });

    test('shouldPreserveAllRolesFromRepository', () async {
      for (final role in StoryRole.values) {
        final repository = FakeStoryRepository()
          ..storyResult = userStory(role: role);
        final container = createContainer(repository);
        addTearDown(container.dispose);

        final state = await container.read(
          storyDetailsProvider('story-${role.name}').future,
        );

        expect(state.userStory?.role, role);
      }
    });

    test('shouldExposeKnownFailureAsTypedLoadFailure', () async {
      final repository = FakeStoryRepository()
        ..getStoryFailures.add(
          const StoryApplicationException(StoryUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(storyDetailsProvider('story-1').future);

      expect(state.userStory, isNull);
      expect(state.loadFailure, const StoryUnauthorized());
    });

    test('shouldExposeUnexpectedFailureAsAsyncError', () async {
      final repository = FakeStoryRepository()
        ..getStoryFailures.add(const UnexpectedStoryException());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final errorState = Completer<AsyncValue<StoryDetailsState>>();
      final subscription = container.listen(
        storyDetailsProvider('story-1'),
        (previous, next) {
          if (next.hasError && !errorState.isCompleted) {
            errorState.complete(next);
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final state = await errorState.future;

      expect(state.hasError, isTrue);
      expect(state.error, isA<UnexpectedStoryException>());
    });

    test('shouldRejectBlankStoryIdWithoutRepositoryCall', () async {
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(storyDetailsProvider('   ').future);

      expect(state.loadFailure, const StoryNotFound());
      expect(repository.getStoryCalls, 0);
    });
  });

  group('StoryDetailsNotifier retry', () {
    test('shouldRetryAfterKnownFailure', () async {
      final repository = FakeStoryRepository()
        ..getStoryFailures.add(
          const StoryApplicationException(StoryNetworkUnavailable()),
        )
        ..storyResults.add(ownerStory);
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);

      await container
          .read(storyDetailsProvider('story-1').notifier)
          .retryLoad();

      expect(repository.getStoryCalls, 2);
      expect(readState(container, 'story-1').userStory, ownerStory);
      expect(readState(container, 'story-1').loadFailure, isNull);
    });

    test('shouldIgnoreDuplicateRetryWhileLoading', () async {
      final retryCompleter = Completer<UserStory>();
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);
      repository.getStoryCompleter = retryCompleter;

      final notifier = container.read(storyDetailsProvider('story-1').notifier);
      final firstRetry = notifier.retryLoad();
      await pumpEventQueue();
      await notifier.retryLoad();

      expect(repository.getStoryCalls, 2);

      retryCompleter.complete(ownerStory);
      await firstRetry;
    });
  });

  group('StoryDetailsNotifier refresh', () {
    test('shouldPreserveStoryWhileRefreshing', () async {
      final refreshCompleter = Completer<UserStory>();
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);
      repository.getStoryCompleter = refreshCompleter;

      final refresh = container
          .read(storyDetailsProvider('story-1').notifier)
          .refreshStory();
      await pumpEventQueue();

      final state = readState(container, 'story-1');
      expect(state.userStory, ownerStory);
      expect(state.isRefreshing, isTrue);

      refreshCompleter.complete(coOwnerStory);
      await refresh;
    });

    test('shouldReplaceStoryWithAuthoritativeRefreshResult', () async {
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);
      repository.storyResult = updatedOwnerStory;

      await container
          .read(storyDetailsProvider('story-1').notifier)
          .refreshStory();

      final state = readState(container, 'story-1');
      expect(state.userStory, updatedOwnerStory);
      expect(state.isRefreshing, isFalse);
      expect(state.refreshFailure, isNull);
    });

    test('shouldKeepStoryAndExposeRefreshFailureForKnownFailure', () async {
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);
      repository.getStoryFailures.add(
        const StoryApplicationException(StoryRequestTimedOut()),
      );

      await container
          .read(storyDetailsProvider('story-1').notifier)
          .refreshStory();

      final state = readState(container, 'story-1');
      expect(state.userStory, ownerStory);
      expect(state.isRefreshing, isFalse);
      expect(state.refreshFailure, const StoryRequestTimedOut());
    });

    test('shouldExposeUnexpectedRefreshFailureAsAsyncError', () async {
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);
      repository.getStoryFailures.add(const UnexpectedStoryException());

      await container
          .read(storyDetailsProvider('story-1').notifier)
          .refreshStory();

      expect(
        container.read(storyDetailsProvider('story-1')),
        isA<AsyncError<StoryDetailsState>>(),
      );
    });

    test('shouldIgnoreDuplicateRefreshWhileRefreshing', () async {
      final refreshCompleter = Completer<UserStory>();
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);
      repository.getStoryCompleter = refreshCompleter;

      final notifier = container.read(storyDetailsProvider('story-1').notifier);
      final firstRefresh = notifier.refreshStory();
      await pumpEventQueue();
      await notifier.refreshStory();

      expect(repository.getStoryCalls, 2);

      refreshCompleter.complete(ownerStory);
      await firstRefresh;
    });

    test('shouldIgnoreRefreshWhenInitialLoadFailed', () async {
      final repository = FakeStoryRepository()
        ..getStoryFailures.add(
          const StoryApplicationException(StoryNotFound()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);

      await container
          .read(storyDetailsProvider('story-1').notifier)
          .refreshStory();

      expect(repository.getStoryCalls, 1);
    });
  });

  group('StoryDetailsNotifier apply updated story', () {
    test('shouldPreserveProjectionMetadataForStoryMutation', () async {
      final preview = storyPreviewPhoto(mediaId: 'media-a');
      final enrichedOwnerStory = userStory(
        memoryCount: 12,
        participantCount: 2,
        previewPhoto: preview,
      );
      final repository = FakeStoryRepository()..storyResult = enrichedOwnerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);

      container
          .read(storyDetailsProvider('story-1').notifier)
          .applyUpdatedStory(updatedOwnerStory);

      final state = readState(container, 'story-1');
      expect(
        state.userStory,
        enrichedOwnerStory.withStoryMutation(updatedOwnerStory.story),
      );
      expect(state.userStory?.role, StoryRole.owner);
      expect(state.userStory?.memoryCount, 12);
      expect(state.userStory?.participantCount, 2);
      expect(state.userStory?.previewPhoto, same(preview));
      expect(repository.getStoryCalls, 1);
    });

    test('shouldIgnoreMismatchedUpdatedStory', () async {
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);

      container
          .read(storyDetailsProvider('story-1').notifier)
          .applyUpdatedStory(userStory(id: 'other-story'));

      expect(readState(container, 'story-1').userStory, ownerStory);
    });
  });

  group('StoryDetailsNotifier authoritative read', () {
    test('shouldReplaceAllProjectionFields', () async {
      final preview = storyPreviewPhoto(mediaId: 'media-new');
      final authoritative = userStory(
        id: ownerStory.story.id,
        title: 'Authoritative story',
        role: StoryRole.coOwner,
        memoryCount: 44,
        participantCount: 5,
        previewPhoto: preview,
      );
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);

      container
          .read(storyDetailsProvider('story-1').notifier)
          .applyAuthoritativeRead(authoritative);

      expect(readState(container, 'story-1').userStory, authoritative);
    });

    test('shouldClearPreviewWhenAuthoritativeReadHasNullPreview', () async {
      final oldPreview = storyPreviewPhoto(mediaId: 'media-old');
      final existing = userStory(previewPhoto: oldPreview);
      final authoritative = userStory(id: existing.story.id);
      final repository = FakeStoryRepository()..storyResult = existing;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);

      container
          .read(storyDetailsProvider('story-1').notifier)
          .applyAuthoritativeRead(authoritative);

      expect(readState(container, 'story-1').userStory?.previewPhoto, isNull);
    });

    test('shouldIgnoreMismatchedAuthoritativeRead', () async {
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('story-1').future);

      container
          .read(storyDetailsProvider('story-1').notifier)
          .applyAuthoritativeRead(userStory(id: 'other-story'));

      expect(readState(container, 'story-1').userStory, ownerStory);
    });
  });

  group('StoryDetailsNotifier security', () {
    test('shouldNotExposeStoryDetailsThroughNotifierStateToString', () async {
      final repository = FakeStoryRepository()
        ..storyResult = userStory(
          id: 'private-story-id',
          title: 'Private title',
          description: 'Private description',
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyDetailsProvider('private-story-id').future);

      final text = container.read(storyDetailsProvider('private-story-id'))
          .toString();

      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('Dio')));
      expect(text, isNot(contains('token')));
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

StoryDetailsState readState(ProviderContainer container, String storyId) {
  return container.read(storyDetailsProvider(storyId)).asData!.value;
}

UserStory userStory({
  String id = 'story-1',
  String title = 'First story',
  String? description = 'First description',
  StoryRole role = StoryRole.owner,
  int memoryCount = 0,
  int participantCount = 1,
  StoryPhotoPreview? previewPhoto,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: title,
      description: description,
      createdAt: DateTime.utc(2026, 1, 1),
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
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

final UserStory ownerStory = userStory();
final UserStory coOwnerStory = userStory(
  id: 'story-2',
  title: 'Second story',
  role: StoryRole.coOwner,
);
final UserStory updatedOwnerStory = userStory(
  id: ownerStory.story.id,
  title: 'Updated story',
  description: 'Updated description',
  role: StoryRole.coOwner,
);

final class FakeStoryRepository implements StoryRepository {
  int createCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateStoryCalls = 0;

  String? receivedStoryId;
  UserStory storyResult = ownerStory;
  final List<UserStory> storyResults = <UserStory>[];
  final List<Object> getStoryFailures = <Object>[];
  Completer<UserStory>? getStoryCompleter;

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    createCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
    receivedStoryId = storyId;

    final completer = getStoryCompleter;
    if (completer != null) {
      getStoryCompleter = null;
      return completer.future;
    }

    if (getStoryFailures.isNotEmpty) {
      throw getStoryFailures.removeAt(0);
    }

    if (storyResults.isNotEmpty) {
      return storyResults.removeAt(0);
    }

    return storyResult;
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    updateStoryCalls += 1;
    throw UnimplementedError();
  }
}

final class UnexpectedStoryException implements Exception {
  const UnexpectedStoryException();
}
