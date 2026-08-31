import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/story/application/edit_story_notifier.dart';
import 'package:memory_map/features/story/application/edit_story_state.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/story_update_field.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('EditStoryNotifier startup', () {
    test('shouldStartIdle', () async {
      final repository = FakeStoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(editStoryProvider('story-1').future);

      expect(state, const EditStoryState());
      expect(repository.updateStoryCalls, 0);
    });
  });

  group('EditStoryNotifier save', () {
    test('shouldSendExactInputAndReturnExactUserStory', () async {
      final repository = FakeStoryRepository()
        ..updateStoryResult = updatedOwnerStory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editStoryProvider('story-1').future);
      final input = titleInput();

      final result = await container
          .read(editStoryProvider('story-1').notifier)
          .save(input);

      expect(repository.updateStoryCalls, 1);
      expect(repository.receivedInput, input);
      expect(result, updatedOwnerStory);
      expect(readState(container, 'story-1').isSaving, isFalse);
      expect(readState(container, 'story-1').saveFailure, isNull);
    });

    test('shouldExposeSavingWhileRepositoryCallIsPending', () async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()
        ..updateStoryCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editStoryProvider('story-1').future);

      final save = container
          .read(editStoryProvider('story-1').notifier)
          .save(titleInput());
      await pumpEventQueue();

      expect(readState(container, 'story-1').isSaving, isTrue);

      completer.complete(updatedOwnerStory);
      await save;
      expect(readState(container, 'story-1').isSaving, isFalse);
    });

    test('shouldExposeKnownFailuresAsTypedSaveFailure', () async {
      const failures = <StoryFailure>[
        StoryValidationFailure(),
        StoryUnauthorized(),
        StoryNotFound(),
        StoryNetworkUnavailable(),
        StoryRequestTimedOut(),
        StoryServerFailure(),
        UnknownStoryFailure(),
      ];

      for (final failure in failures) {
        final repository = FakeStoryRepository()
          ..updateStoryFailure = StoryApplicationException(failure);
        final container = createContainer(repository);
        addTearDown(container.dispose);
        await container.read(editStoryProvider('story-1').future);

        final result = await container
            .read(editStoryProvider('story-1').notifier)
            .save(titleInput());

        expect(result, isNull);
        expect(readState(container, 'story-1').isSaving, isFalse);
        expect(readState(container, 'story-1').saveFailure, failure);
      }
    });

    test('shouldExposeUnexpectedFailureAsAsyncErrorAndResetSaving', () async {
      final repository = FakeStoryRepository()
        ..updateStoryFailure = const UnexpectedStoryException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editStoryProvider('story-1').future);

      final result = await container
          .read(editStoryProvider('story-1').notifier)
          .save(titleInput());

      final value = container.read(editStoryProvider('story-1'));
      expect(result, isNull);
      expect(value, isA<AsyncError<EditStoryState>>());
      expect(value.error, isA<UnexpectedStoryException>());
    });

    test('shouldIgnoreDuplicateSaveWhileSaving', () async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()
        ..updateStoryCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editStoryProvider('story-1').future);
      final notifier = container.read(editStoryProvider('story-1').notifier);

      final firstSave = notifier.save(titleInput());
      await pumpEventQueue();
      final secondResult = await notifier.save(titleInput());

      expect(secondResult, isNull);
      expect(repository.updateStoryCalls, 1);

      completer.complete(updatedOwnerStory);
      await firstSave;
    });

    test('shouldRejectInputForDifferentStoryIdWithoutRepositoryCall', () async {
      final repository = FakeStoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editStoryProvider('story-1').future);

      await expectLater(
        container
            .read(editStoryProvider('story-1').notifier)
            .save(titleInput(storyId: 'other-story')),
        throwsA(
          argumentErrorWithMessage('input storyId must match provider storyId'),
        ),
      );
      expect(repository.updateStoryCalls, 0);
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

EditStoryState readState(ProviderContainer container, String storyId) {
  return container.read(editStoryProvider(storyId)).asData!.value;
}

UpdateStoryInput titleInput({String storyId = 'story-1'}) {
  return UpdateStoryInput(
    storyId: storyId,
    title: const StoryUpdateField<String>.provided('Updated story'),
  );
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}

UserStory userStory({
  String id = 'story-1',
  String title = 'First story',
  String? description = 'First description',
  StoryRole role = StoryRole.owner,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: title,
      description: description,
      createdAt: DateTime.utc(2026, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: role,
  );
}

final UserStory updatedOwnerStory = userStory(
  title: 'Updated story',
  description: 'Updated description',
);

final class FakeStoryRepository implements StoryRepository {
  int createCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateStoryCalls = 0;

  UpdateStoryInput? receivedInput;
  UserStory updateStoryResult = updatedOwnerStory;
  Object? updateStoryFailure;
  Completer<UserStory>? updateStoryCompleter;

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
    throw UnimplementedError();
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    updateStoryCalls += 1;
    receivedInput = input;

    final completer = updateStoryCompleter;
    if (completer != null) {
      updateStoryCompleter = null;
      return completer.future;
    }

    final failure = updateStoryFailure;
    if (failure != null) {
      throw failure;
    }

    return updateStoryResult;
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
