import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/story/application/delete_story_notifier.dart';
import 'package:memory_map/features/story/application/delete_story_state.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('DeleteStoryNotifier', () {
    test('shouldDeleteStoryAndRemoveItFromLoadedStories', () async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, otherStory];
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      await container.read(deleteStoryProvider(ownerStory.story.id).future);

      final result = await container
          .read(deleteStoryProvider(ownerStory.story.id).notifier)
          .deleteStory();

      expect(result, isTrue);
      expect(repository.deleteStoryCalls, 1);
      expect(repository.receivedDeleteStoryId, ownerStory.story.id);
      expect(container.read(deleteStoryProvider(ownerStory.story.id)).value,
          const DeleteStoryState());
      expect(
        container
            .read(storiesNotifierProvider)
            .asData!
            .value
            .stories
            .map((story) => story.story.id),
        <String>[otherStory.story.id],
      );
    });

    test('shouldIgnoreDuplicateDeleteWhileRequestIsActive', () async {
      final completer = Completer<void>();
      final repository = FakeStoryRepository()..deleteCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final provider = deleteStoryProvider(ownerStory.story.id);
      final subscription = container.listen(
        provider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      final first = notifier.deleteStory();
      await pumpEventQueue();
      final second = await notifier.deleteStory();

      expect(second, isFalse);
      expect(repository.deleteStoryCalls, 1);

      completer.complete();
      expect(await first, isTrue);
    });

    test('shouldExposeKnownFailureAndAllowRetry', () async {
      final repository = FakeStoryRepository()
        ..deleteFailure =
            const StoryApplicationException(StoryNetworkUnavailable());
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteStoryProvider(ownerStory.story.id).future);
      final notifier =
          container.read(deleteStoryProvider(ownerStory.story.id).notifier);

      expect(await notifier.deleteStory(), isFalse);

      final failedState = container
          .read(deleteStoryProvider(ownerStory.story.id))
          .asData!
          .value;
      expect(failedState.isDeleting, isFalse);
      expect(failedState.deleteFailure, const StoryNetworkUnavailable());

      repository.deleteFailure = null;
      expect(await notifier.deleteStory(), isTrue);
      expect(repository.deleteStoryCalls, 2);
    });

    test('shouldRejectBlankStoryIdWithoutRepositoryCall', () async {
      final repository = FakeStoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(deleteStoryProvider('   ').future);

      final result =
          await container.read(deleteStoryProvider('   ').notifier).deleteStory();

      expect(result, isFalse);
      expect(repository.deleteStoryCalls, 0);
      expect(
        container.read(deleteStoryProvider('   ')).asData!.value.deleteFailure,
        const StoryValidationFailure(),
      );
    });

    test('shouldIgnoreCompletedDeleteAfterProviderInvalidation', () async {
      final completer = Completer<void>();
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory, otherStory]
        ..deleteCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      final provider = deleteStoryProvider(ownerStory.story.id);
      final subscription = container.listen(
        provider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      final delete = notifier.deleteStory();
      await pumpEventQueue();

      expect(repository.deleteStoryCalls, 1);
      expect(container.read(provider).asData!.value.isDeleting, isTrue);

      container.invalidate(provider);
      await pumpEventQueue();
      await container.read(provider.future);

      completer.complete();
      expect(await delete, isFalse);
      expect(container.read(provider).asData!.value, const DeleteStoryState());
      expect(
        container.read(storiesNotifierProvider).asData!.value.stories,
        <UserStory>[ownerStory, otherStory],
      );
    });

    test('shouldIgnoreCompletedDeleteAfterProviderDisposal', () async {
      final completer = Completer<void>();
      final repository = FakeStoryRepository()..deleteCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final provider = deleteStoryProvider(ownerStory.story.id);
      final subscription = container.listen(
        provider,
        (previous, next) {},
        fireImmediately: true,
      );
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      final delete = notifier.deleteStory();
      await pumpEventQueue();

      expect(repository.deleteStoryCalls, 1);

      subscription.close();
      container.invalidate(provider);
      await pumpEventQueue();

      completer.complete();
      expect(await delete, isFalse);
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

final UserStory ownerStory = userStory(id: 'story-1');
final UserStory otherStory = userStory(id: 'story-2');

UserStory userStory({
  required String id,
  StoryRole role = StoryRole.owner,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: 'Our story',
      description: 'Together since 2021',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: role,
  );
}

final class FakeStoryRepository implements StoryRepository {
  int getStoriesCalls = 0;
  int deleteStoryCalls = 0;
  String? receivedDeleteStoryId;
  List<UserStory> storiesResult = <UserStory>[ownerStory];
  Object? deleteFailure;
  Completer<void>? deleteCompleter;

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteStory({required String storyId}) async {
    deleteStoryCalls += 1;
    receivedDeleteStoryId = storyId;
    final failure = deleteFailure;
    if (failure != null) {
      throw failure;
    }

    final completer = deleteCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    return storiesResult;
  }

  @override
  Future<UserStory> getStory(String storyId) {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> removeStoryCover({required String storyId}) {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> uploadStoryCover({
    required String storyId,
    required PreparedPhotoUpload photo,
  }) {
    throw UnimplementedError();
  }
}
