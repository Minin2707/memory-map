import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/stories_state.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('StoriesNotifier startup', () {
    test('shouldStartWithAsyncLoading', () async {
      final completer = Completer<List<UserStory>>();
      final repository = FakeStoryRepository()
        ..getStoriesCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final future = container.read(storiesNotifierProvider.future);

      expect(
        container.read(storiesNotifierProvider),
        isA<AsyncLoading<StoriesState>>(),
      );

      completer.complete(<UserStory>[]);
      await future;
    });

    test('shouldLoadStoriesFromRepository', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, coOwnerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(storiesNotifierProvider.future);

      expect(state.stories, <UserStory>[ownerStory, coOwnerStory]);
      expect(state.loadFailure, isNull);
      expect(repository.getStoriesCalls, 1);
    });

    test('shouldRepresentEmptyLoadedListWithoutFailure', () async {
      final container = createContainer(FakeStoryRepository());
      addTearDown(container.dispose);

      final state = await container.read(storiesNotifierProvider.future);

      expect(state.stories, isEmpty);
      expect(state.loadFailure, isNull);
    });

    test('shouldExposeKnownLoadFailureAsState', () async {
      final repository = FakeStoryRepository()
        ..getStoriesFailures.add(
          const StoryApplicationException(StoryUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(storiesNotifierProvider.future);

      expect(state.stories, isEmpty);
      expect(state.loadFailure, const StoryUnauthorized());
    });

    test('shouldExposeUnexpectedLoadFailureAsAsyncError', () async {
      final repository = FakeStoryRepository()
        ..getStoriesFailures.add(const UnexpectedStoryException());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final errorState = Completer<AsyncValue<StoriesState>>();
      final subscription = container.listen(
        storiesNotifierProvider,
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
  });

  group('StoriesNotifier retry', () {
    test('shouldRetryLoadAfterKnownFailure', () async {
      final repository = FakeStoryRepository()
        ..getStoriesFailures.add(
          const StoryApplicationException(StoryNetworkUnavailable()),
        )
        ..storiesResults.add(<UserStory>[ownerStory]);
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      await container.read(storiesNotifierProvider.notifier).retryLoad();

      expect(repository.getStoriesCalls, 2);
      expect(readState(container).stories, <UserStory>[ownerStory]);
      expect(readState(container).loadFailure, isNull);
    });

    test('shouldShowLoadingDuringRetry', () async {
      final retryCompleter = Completer<List<UserStory>>();
      final repository = FakeStoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      repository.getStoriesCompleter = retryCompleter;

      final retry = container.read(storiesNotifierProvider.notifier).retryLoad();
      await pumpEventQueue();

      expect(
        container.read(storiesNotifierProvider),
        isA<AsyncLoading<StoriesState>>(),
      );

      retryCompleter.complete(<UserStory>[ownerStory]);
      await retry;
    });

    test('shouldIgnoreConcurrentRetryWhileLoading', () async {
      final retryCompleter = Completer<List<UserStory>>();
      final repository = FakeStoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      repository.getStoriesCompleter = retryCompleter;

      final notifier = container.read(storiesNotifierProvider.notifier);
      final firstRetry = notifier.retryLoad();
      await pumpEventQueue();
      await notifier.retryLoad();

      expect(repository.getStoriesCalls, 2);

      retryCompleter.complete(<UserStory>[ownerStory]);
      await firstRetry;
    });
  });

  group('StoriesNotifier refresh', () {
    test('shouldPreserveStoriesWhileRefreshing', () async {
      final refreshCompleter = Completer<List<UserStory>>();
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      repository.getStoriesCompleter = refreshCompleter;

      final refresh =
          container.read(storiesNotifierProvider.notifier).refreshStories();
      await pumpEventQueue();

      final state = readState(container);
      expect(state.stories, <UserStory>[ownerStory]);
      expect(state.isRefreshing, isTrue);

      refreshCompleter.complete(<UserStory>[coOwnerStory]);
      await refresh;
    });

    test('shouldReplaceStoriesWithAuthoritativeRefreshResult', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      repository.storiesResult = <UserStory>[coOwnerStory, ownerStory];

      await container.read(storiesNotifierProvider.notifier).refreshStories();

      final state = readState(container);
      expect(state.stories, <UserStory>[coOwnerStory, ownerStory]);
      expect(state.isRefreshing, isFalse);
      expect(state.refreshFailure, isNull);
    });

    test('shouldKeepStoriesAndExposeRefreshFailureForKnownFailure', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      repository.getStoriesFailures.add(
        const StoryApplicationException(StoryRequestTimedOut()),
      );

      await container.read(storiesNotifierProvider.notifier).refreshStories();

      final state = readState(container);
      expect(state.stories, <UserStory>[ownerStory]);
      expect(state.isRefreshing, isFalse);
      expect(state.refreshFailure, const StoryRequestTimedOut());
    });

    test('shouldExposeUnexpectedRefreshFailureAsAsyncError', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      repository.getStoriesFailures.add(const UnexpectedStoryException());

      await container.read(storiesNotifierProvider.notifier).refreshStories();

      expect(
        container.read(storiesNotifierProvider),
        isA<AsyncError<StoriesState>>(),
      );
    });

    test('shouldIgnoreRefreshWhileAlreadyRefreshing', () async {
      final refreshCompleter = Completer<List<UserStory>>();
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      repository.getStoriesCompleter = refreshCompleter;

      final notifier = container.read(storiesNotifierProvider.notifier);
      final firstRefresh = notifier.refreshStories();
      await pumpEventQueue();
      await notifier.refreshStories();

      expect(repository.getStoriesCalls, 2);

      refreshCompleter.complete(<UserStory>[ownerStory]);
      await firstRefresh;
    });

    test('shouldIgnoreRefreshWhenLoadFailed', () async {
      final repository = FakeStoryRepository()
        ..getStoriesFailures.add(
          const StoryApplicationException(StoryUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      await container.read(storiesNotifierProvider.notifier).refreshStories();

      expect(repository.getStoriesCalls, 1);
    });
  });

  group('StoriesNotifier create', () {
    test('shouldCreateStoryThenLoadAuthoritativeStoryProjection', () async {
      final authoritativeStory = UserStory(
        story: createdStory,
        role: StoryRole.owner,
        memoryCount: 0,
        participantCount: 1,
      );
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory]
        ..createResult = createdStory
        ..storyResult = authoritativeStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      final result = await container
          .read(storiesNotifierProvider.notifier)
          .createStory(title: 'Created title', description: null);

      expect(result, createdStory);
      expect(repository.createdTitle, 'Created title');
      expect(repository.createdDescription, isNull);
      expect(repository.operations, <String>[
        'getStories',
        'createStory',
        'getStory',
      ]);
      expect(
        readState(container).stories,
        <UserStory>[ownerStory, authoritativeStory],
      );
    });

    test('shouldExposeCreatingStateWhileCreateIsInProgress', () async {
      final createCompleter = Completer<Story>();
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory]
        ..createCompleter = createCompleter;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      final create = container
          .read(storiesNotifierProvider.notifier)
          .createStory(title: 'Created title');
      await pumpEventQueue();

      final state = readState(container);
      expect(state.isCreating, isTrue);
      expect(state.stories, <UserStory>[ownerStory]);

      createCompleter.complete(createdStory);
      await create;
    });

    test('shouldKeepStoriesAndExposeCreateFailureForKnownFailure', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory]
        ..createFailure = const StoryApplicationException(
          StoryValidationFailure(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      final result = await container
          .read(storiesNotifierProvider.notifier)
          .createStory(title: 'Created title');

      final state = readState(container);
      expect(result, isNull);
      expect(state.stories, <UserStory>[ownerStory]);
      expect(state.isCreating, isFalse);
      expect(state.createFailure, const StoryValidationFailure());
      expect(repository.getStoriesCalls, 1);
    });

    test('shouldReturnCreatedStoryWhenPostCreateProjectionLoadHasKnownFailure',
        () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory]
        ..createResult = createdStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      repository.getStoryFailures.add(
        const StoryApplicationException(StoryNetworkUnavailable()),
      );

      final result = await container
          .read(storiesNotifierProvider.notifier)
          .createStory(title: 'Created title');

      final state = readState(container);
      expect(result, createdStory);
      expect(state.stories, <UserStory>[ownerStory]);
      expect(state.isCreating, isFalse);
      expect(state.createFailure, isNull);
      expect(state.refreshFailure, const StoryNetworkUnavailable());
    });

    test('shouldExposeUnexpectedCreateFailureAsAsyncError', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory]
        ..createFailure = const UnexpectedStoryException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      final result = await container
          .read(storiesNotifierProvider.notifier)
          .createStory(title: 'Created title');

      expect(result, isNull);
      expect(
        container.read(storiesNotifierProvider),
        isA<AsyncError<StoriesState>>(),
      );
    });

    test('shouldIgnoreCreateDuringInitialLoading', () async {
      final completer = Completer<List<UserStory>>();
      final repository = FakeStoryRepository()
        ..getStoriesCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final load = container.read(storiesNotifierProvider.future);
      await pumpEventQueue();
      final result = await container
          .read(storiesNotifierProvider.notifier)
          .createStory(title: 'Created title');

      expect(result, isNull);
      expect(repository.createCalls, 0);

      completer.complete(<UserStory>[]);
      await load;
    });

    test('shouldIgnoreCreateDuringRefresh', () async {
      final refreshCompleter = Completer<List<UserStory>>();
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      repository.getStoriesCompleter = refreshCompleter;

      final refresh =
          container.read(storiesNotifierProvider.notifier).refreshStories();
      await pumpEventQueue();
      final result = await container
          .read(storiesNotifierProvider.notifier)
          .createStory(title: 'Created title');

      expect(result, isNull);
      expect(repository.createCalls, 0);

      refreshCompleter.complete(<UserStory>[ownerStory]);
      await refresh;
    });

    test('shouldIgnoreDuplicateCreateWhileCreating', () async {
      final createCompleter = Completer<Story>();
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory]
        ..createCompleter = createCompleter;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      final notifier = container.read(storiesNotifierProvider.notifier);
      final firstCreate = notifier.createStory(title: 'Created title');
      await pumpEventQueue();
      final secondCreate = await notifier.createStory(title: 'Other title');

      expect(secondCreate, isNull);
      expect(repository.createCalls, 1);

      createCompleter.complete(createdStory);
      await firstCreate;
    });

    test('shouldIgnoreRefreshDuringCreate', () async {
      final createCompleter = Completer<Story>();
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory]
        ..createCompleter = createCompleter;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      final create = container
          .read(storiesNotifierProvider.notifier)
          .createStory(title: 'Created title');
      await pumpEventQueue();
      await container.read(storiesNotifierProvider.notifier).refreshStories();

      expect(repository.getStoriesCalls, 1);

      createCompleter.complete(createdStory);
      await create;
    });
  });

  group('StoriesNotifier apply updated story', () {
    test('shouldPreserveProjectionMetadataForStoryMutation', () async {
      final preview = storyPreviewPhoto(mediaId: 'media-a');
      final enrichedOwnerStory = userStory(
        memoryCount: 12,
        participantCount: 2,
        previewPhoto: preview,
      );
      final updatedOwnerStory = userStory(
        id: ownerStory.story.id,
        title: 'Updated title',
        role: StoryRole.coOwner,
      );
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[enrichedOwnerStory, coOwnerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storiesNotifierProvider.notifier)
          .applyUpdatedStory(updatedOwnerStory);

      expect(
        readState(container).stories.first,
        enrichedOwnerStory.withStoryMutation(updatedOwnerStory.story),
      );
      expect(readState(container).stories.first.role, StoryRole.owner);
      expect(readState(container).stories.first.memoryCount, 12);
      expect(readState(container).stories.first.participantCount, 2);
      expect(readState(container).stories.first.previewPhoto, same(preview));
      expect(repository.operations, <String>['getStories']);
    });

    test('shouldNotAppendUnknownUpdatedStory', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storiesNotifierProvider.notifier)
          .applyUpdatedStory(userStory(id: 'unknown-story'));

      expect(readState(container).stories, <UserStory>[ownerStory]);
    });

    test('shouldIgnoreUpdatedStoryWhenLoadFailed', () async {
      final repository = FakeStoryRepository()
        ..getStoriesFailures.add(
          const StoryApplicationException(StoryUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storiesNotifierProvider.notifier)
          .applyUpdatedStory(ownerStory);

      expect(readState(container).stories, isEmpty);
      expect(readState(container).loadFailure, const StoryUnauthorized());
    });
  });

  group('StoriesNotifier authoritative read', () {
    test('shouldReplaceAllProjectionFieldsWithoutChangingOrder', () async {
      final preview = storyPreviewPhoto(mediaId: 'media-new');
      final authoritative = userStory(
        id: ownerStory.story.id,
        title: 'Authoritative title',
        role: StoryRole.coOwner,
        memoryCount: 44,
        participantCount: 5,
        previewPhoto: preview,
      );
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, coOwnerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storiesNotifierProvider.notifier)
          .applyAuthoritativeRead(authoritative);

      expect(
        readState(container).stories,
        <UserStory>[authoritative, coOwnerStory],
      );
    });

    test('shouldClearPreviewWhenAuthoritativeReadHasNullPreview', () async {
      final oldPreview = storyPreviewPhoto(mediaId: 'media-old');
      final existing = userStory(previewPhoto: oldPreview);
      final authoritative = userStory(
        id: existing.story.id,
        previewPhoto: null,
      );
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[existing];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storiesNotifierProvider.notifier)
          .applyAuthoritativeRead(authoritative);

      expect(readState(container).stories.single.previewPhoto, isNull);
    });

    test('shouldIgnoreUnknownAuthoritativeRead', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storiesNotifierProvider.notifier)
          .applyAuthoritativeRead(userStory(id: 'unknown-story'));

      expect(readState(container).stories, <UserStory>[ownerStory]);
    });
  });

  group('StoriesNotifier upsert user story', () {
    test('shouldAppendAcceptedStoryWhenMissing', () async {
      final acceptedStory = userStory(
        id: 'accepted-story',
        title: 'A story that would sort first by title',
        role: StoryRole.viewer,
      );
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, coOwnerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      final originalStories = readState(container).stories;

      container
          .read(storiesNotifierProvider.notifier)
          .upsertUserStory(acceptedStory);

      final stories = readState(container).stories;
      expect(
        stories,
        <UserStory>[ownerStory, coOwnerStory, acceptedStory],
      );
      expect(stories.last, same(acceptedStory));
      expect(stories.last.role, StoryRole.viewer);
      expect(originalStories, <UserStory>[ownerStory, coOwnerStory]);
      expect(identical(stories, originalStories), isFalse);
      expect(
        () => stories.add(userStory(id: 'mutation-attempt')),
        throwsA(isA<UnsupportedError>()),
      );
      expect(repository.operations, <String>['getStories']);
    });

    test('shouldReplaceExistingAcceptedStoryWithoutChangingOrder', () async {
      final thirdStory = userStory(
        id: 'story-3',
        title: 'Third story',
        role: StoryRole.viewer,
      );
      final updatedCoOwnerStory = userStory(
        id: coOwnerStory.story.id,
        title: 'Accepted update',
        role: StoryRole.viewer,
      );
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, coOwnerStory, thirdStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storiesNotifierProvider.notifier)
          .upsertUserStory(updatedCoOwnerStory);

      final stories = readState(container).stories;
      expect(
        stories,
        <UserStory>[ownerStory, updatedCoOwnerStory, thirdStory],
      );
      expect(stories.length, 3);
      expect(
        stories.where(
          (userStory) => userStory.story.id == coOwnerStory.story.id,
        ),
        <UserStory>[updatedCoOwnerStory],
      );
      expect(stories[1], same(updatedCoOwnerStory));
      expect(stories[1].role, StoryRole.viewer);
    });

    test('shouldAppendOnceThenReplaceRepeatedAcceptedStoryAtSamePosition',
        () async {
      final acceptedStory = userStory(
        id: 'accepted-story',
        title: 'Accepted story',
        role: StoryRole.viewer,
      );
      final updatedAcceptedStory = userStory(
        id: acceptedStory.story.id,
        title: 'Accepted story updated',
        role: StoryRole.coOwner,
      );
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, coOwnerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      final notifier = container.read(storiesNotifierProvider.notifier);

      notifier.upsertUserStory(acceptedStory);
      notifier.upsertUserStory(updatedAcceptedStory);

      final stories = readState(container).stories;
      expect(
        stories,
        <UserStory>[ownerStory, coOwnerStory, updatedAcceptedStory],
      );
      expect(
        stories.where(
          (userStory) => userStory.story.id == acceptedStory.story.id,
        ),
        <UserStory>[updatedAcceptedStory],
      );
      expect(stories.last, same(updatedAcceptedStory));
      expect(stories.last.role, StoryRole.coOwner);
    });

    test('shouldIgnoreUpsertWhenLoadFailed', () async {
      final repository = FakeStoryRepository()
        ..getStoriesFailures.add(
          const StoryApplicationException(StoryUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storiesNotifierProvider.notifier)
          .upsertUserStory(ownerStory);

      expect(readState(container).stories, isEmpty);
      expect(readState(container).loadFailure, const StoryUnauthorized());
    });
  });

  group('StoriesNotifier remove story by id', () {
    test('shouldRemoveMatchingStoryWithoutChangingRemainingOrder', () async {
      final thirdStory = userStory(
        id: 'story-3',
        title: 'Third story',
        role: StoryRole.viewer,
      );
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, coOwnerStory, thirdStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      final originalStories = readState(container).stories;

      container
          .read(storiesNotifierProvider.notifier)
          .removeStoryById(coOwnerStory.story.id);

      final stories = readState(container).stories;
      expect(stories, <UserStory>[ownerStory, thirdStory]);
      expect(stories.first, same(ownerStory));
      expect(stories.last, same(thirdStory));
      expect(originalStories, <UserStory>[ownerStory, coOwnerStory, thirdStory]);
      expect(identical(stories, originalStories), isFalse);
      expect(
        () => stories.add(userStory(id: 'mutation-attempt')),
        throwsA(isA<UnsupportedError>()),
      );
      expect(repository.operations, <String>['getStories']);
    });

    test('shouldNoOpWhenStoryIdIsMissing', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, coOwnerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      final originalStories = readState(container).stories;

      container
          .read(storiesNotifierProvider.notifier)
          .removeStoryById('missing-story');

      expect(readState(container).stories, originalStories);
      expect(repository.operations, <String>['getStories']);
    });

    test('shouldRemoveAllAccidentalDuplicateMatches', () async {
      final duplicateOwnerStory = userStory(
        id: ownerStory.story.id,
        title: 'Duplicate owner story',
        role: StoryRole.viewer,
      );
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[
          ownerStory,
          coOwnerStory,
          duplicateOwnerStory,
        ];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storiesNotifierProvider.notifier)
          .removeStoryById(ownerStory.story.id);

      expect(readState(container).stories, <UserStory>[coOwnerStory]);
    });

    test('shouldBeSafeWhenRepeated', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, coOwnerStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      final notifier = container.read(storiesNotifierProvider.notifier);

      notifier.removeStoryById(ownerStory.story.id);
      notifier.removeStoryById(ownerStory.story.id);

      expect(readState(container).stories, <UserStory>[coOwnerStory]);
      expect(repository.operations, <String>['getStories']);
    });

    test('shouldIgnoreRemovalWhenLoadFailed', () async {
      final repository = FakeStoryRepository()
        ..getStoriesFailures.add(
          const StoryApplicationException(StoryUnauthorized()),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      container
          .read(storiesNotifierProvider.notifier)
          .removeStoryById(ownerStory.story.id);

      expect(readState(container).stories, isEmpty);
      expect(readState(container).loadFailure, const StoryUnauthorized());
      expect(repository.operations, <String>['getStories']);
    });
  });

  group('StoriesNotifier security', () {
    test('shouldNotExposeStoryDetailsThroughNotifierStateToString', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[
          userStory(
            id: 'private-story-id',
            title: 'Private title',
            description: 'Private description',
          ),
        ];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      final text = container.read(storiesNotifierProvider).toString();

      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
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

StoriesState readState(ProviderContainer container) {
  return container.read(storiesNotifierProvider).asData!.value;
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

Story story({
  String id = 'story-created',
  String title = 'Created story',
  String? description = 'Created description',
}) {
  return Story(
    id: id,
    title: title,
    description: description,
    createdAt: DateTime.utc(2026, 2),
    updatedAt: DateTime.utc(2026, 2, 2),
  );
}

final UserStory ownerStory = userStory();
final UserStory coOwnerStory = userStory(
  id: 'story-2',
  title: 'Second story',
  role: StoryRole.coOwner,
);
final Story createdStory = story();

final class FakeStoryRepository implements StoryRepository {
  int createCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateCalls = 0;

  String? createdTitle;
  String? createdDescription;
  final List<String> operations = <String>[];
  List<UserStory> storiesResult = <UserStory>[];
  UserStory storyResult = ownerStory;
  final List<UserStory> storyResults = <UserStory>[];
  final List<List<UserStory>> storiesResults = <List<UserStory>>[];
  final List<Object> getStoryFailures = <Object>[];
  final List<Object> getStoriesFailures = <Object>[];
  Completer<List<UserStory>>? getStoriesCompleter;
  Story? createResult;
  Object? createFailure;
  Completer<Story>? createCompleter;

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    createCalls += 1;
    createdTitle = title;
    createdDescription = description;
    operations.add('createStory');

    final completer = createCompleter;
    if (completer != null) {
      createCompleter = null;
      return completer.future;
    }

    final failure = createFailure;
    if (failure != null) {
      throw failure;
    }

    return createResult ?? createdStory;
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
    operations.add('getStory');

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
    operations.add('getStories');

    final completer = getStoriesCompleter;
    if (completer != null) {
      getStoriesCompleter = null;
      return completer.future;
    }

    if (getStoriesFailures.isNotEmpty) {
      throw getStoriesFailures.removeAt(0);
    }

    if (storiesResults.isNotEmpty) {
      return storiesResults.removeAt(0);
    }

    return storiesResult;
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    updateCalls += 1;
    throw UnimplementedError();
  }
}

final class UnexpectedStoryException implements Exception {
  const UnexpectedStoryException();
}
