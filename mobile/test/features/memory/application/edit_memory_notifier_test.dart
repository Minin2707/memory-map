import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/edit_memory_notifier.dart';
import 'package:memory_map/features/memory/application/edit_memory_state.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('EditMemoryNotifier startup', () {
    test('shouldStartIdleWithoutRepositoryCall', () async {
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        editMemoryProvider(memoryA.id).future,
      );

      expect(state, const EditMemoryState());
      expect(repository.getMemoryCalls, 0);
      expect(repository.getMemoriesCalls, 0);
      expect(repository.updateMemoryCalls, 0);
    });
  });

  group('EditMemoryNotifier save', () {
    test('shouldSaveInputReturnAuthoritativeMemoryAndResetState', () async {
      final authoritative = memory(id: memoryA.id, title: 'Server title');
      final repository = FakeMemoryRepository()..updateResult = authoritative;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editMemoryProvider(memoryA.id).future);

      final result = await container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput());

      expect(result, same(authoritative));
      expect(repository.updateMemoryCalls, 1);
      expect(repository.receivedUpdateInput, updateInput());
      expect(readEditState(container, memoryA.id), const EditMemoryState());
      expect(repository.getMemoryCalls, 0);
      expect(repository.getMemoriesCalls, 0);
    });

    test('shouldExposeSavingWhileRepositoryCallIsPending', () async {
      final completer = Completer<Memory>();
      final repository = FakeMemoryRepository()..updateCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editMemoryProvider(memoryA.id).future);

      final save = container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput());
      await pumpEventQueue();

      expect(readEditState(container, memoryA.id).isSaving, isTrue);
      expect(readEditState(container, memoryA.id).saveFailure, isNull);

      completer.complete(memory(id: memoryA.id, title: 'Server title'));
      await save;
      expect(readEditState(container, memoryA.id).isSaving, isFalse);
    });

    test('shouldIgnoreDuplicateSaveWhileSaving', () async {
      final completer = Completer<Memory>();
      final repository = FakeMemoryRepository()..updateCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editMemoryProvider(memoryA.id).future);
      final notifier = container.read(editMemoryProvider(memoryA.id).notifier);

      final firstSave = notifier.save(updateInput());
      await pumpEventQueue();
      final secondResult = await notifier.save(updateInput(title: 'Second'));

      expect(secondResult, isNull);
      expect(repository.updateMemoryCalls, 1);
      expect(readEditState(container, memoryA.id).isSaving, isTrue);

      completer.complete(memory(id: memoryA.id, title: 'Server title'));
      await firstSave;
    });

    test('shouldRejectMismatchedInputMemoryIdWithoutRepositoryCall', () async {
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editMemoryProvider(memoryA.id).future);

      final result = await container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput(memoryId: memoryB.id));

      expect(result, isNull);
      expect(repository.updateMemoryCalls, 0);
      expect(readEditState(container, memoryA.id).isSaving, isFalse);
      expect(
        readEditState(container, memoryA.id).saveFailure,
        const MemoryValidationFailure(),
      );
    });

    test('shouldExposeKnownFailureAndSkipSynchronization', () async {
      final repository = FakeMemoryRepository()
        ..updateFailure = const MemoryApplicationException(
          MemoryUpdateUnavailable(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(editMemoryProvider(memoryA.id).future);

      final result = await container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput());

      expect(result, isNull);
      expect(readEditState(container, memoryA.id).isSaving, isFalse);
      expect(
        readEditState(container, memoryA.id).saveFailure,
        const MemoryUpdateUnavailable(),
      );
      expect(readMemoryDetails(container, memoryA.id), same(memoryA));
      expect(readStoryMemories(container), <Memory>[memoryA]);
    });

    test('shouldExposeUnexpectedFailureAsAsyncErrorAndResetSaving', () async {
      final repository = FakeMemoryRepository()
        ..updateFailure = const UnexpectedMemoryException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editMemoryProvider(memoryA.id).future);

      final result = await container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput());

      final value = container.read(editMemoryProvider(memoryA.id));
      expect(result, isNull);
      expect(value, isA<AsyncError<EditMemoryState>>());
      expect(value.error, isA<UnexpectedMemoryException>());
    });

    test('shouldResetAfterFailure', () async {
      final repository = FakeMemoryRepository()
        ..updateFailure = const MemoryApplicationException(
          MemoryRequestTimedOut(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editMemoryProvider(memoryA.id).future);
      final notifier = container.read(editMemoryProvider(memoryA.id).notifier);
      await notifier.save(updateInput());

      notifier.reset();

      expect(readEditState(container, memoryA.id), const EditMemoryState());
    });
  });

  group('EditMemoryNotifier synchronization', () {
    test('shouldApplyAuthoritativeMemoryToLoadedDetails', () async {
      final updated = memory(id: memoryA.id, title: 'Server updated');
      final repository = FakeMemoryRepository()..updateResult = updated;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      await container.read(editMemoryProvider(memoryA.id).future);

      final result = await container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput());

      expect(result, same(updated));
      expect(readMemoryDetails(container, memoryA.id), same(updated));
      expect(repository.operations, <String>['getMemory', 'updateMemory']);
    });

    test('shouldUpsertAuthoritativeMemoryIntoLoadedStoryMemories', () async {
      final updated = memory(id: memoryA.id, title: 'Updated', day: 20);
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryC]
        ..updateResult = updated;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(editMemoryProvider(memoryA.id).future);

      final result = await container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput());

      expect(result, same(updated));
      expect(readStoryMemories(container), <Memory>[updated, memoryC]);
      expect(repository.operations, <String>['getMemories', 'updateMemory']);
    });

    test('shouldNotForceLoadDetailsOrListProvidersWhenTheyDoNotExist',
        () async {
      final repository = FakeMemoryRepository()
        ..updateResult = memory(id: memoryA.id, title: 'Server title');
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(editMemoryProvider(memoryA.id).future);

      final result = await container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput());

      expect(result, same(repository.updateResult));
      expect(repository.operations, <String>['updateMemory']);
      expect(repository.getMemoryCalls, 0);
      expect(repository.getMemoriesCalls, 0);
    });

    test('shouldReconcileLoadedStorySummaryAfterUpdate', () async {
      final updated = memory(id: memoryA.id, title: 'Updated');
      final memoryRepository = FakeMemoryRepository()..updateResult = updated;
      final storyRepository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory]
        ..storyResult = userStory(memoryCount: 3);
      final container = createContainer(
        memoryRepository,
        storyRepository: storyRepository,
      );
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      await container.read(editMemoryProvider(memoryA.id).future);

      final result = await container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput());

      expect(result, same(updated));
      expect(storyRepository.getStoriesCalls, 1);
      expect(storyRepository.getStoryCalls, 1);
      expect(readStories(container).single.memoryCount, 3);
    });

    test('shouldTreatAuthoritativeMemoryIdMismatchAsUnexpectedAndSkipSync',
        () async {
      final repository = FakeMemoryRepository()..updateResult = memoryB;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(editMemoryProvider(memoryA.id).future);

      final result = await container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput());

      final value = container.read(editMemoryProvider(memoryA.id));
      expect(result, isNull);
      expect(value, isA<AsyncError<EditMemoryState>>());
      expect(value.error, isA<StateError>());
      expect(value.error.toString(), isNot(contains(memoryA.id)));
      expect(value.error.toString(), isNot(contains(memoryB.id)));
      expect(readMemoryDetails(container, memoryA.id), same(memoryA));
      expect(readStoryMemories(container), <Memory>[memoryA]);
    });

    test('shouldTreatAuthoritativeStoryMismatchAsUnexpectedAndSkipSync',
        () async {
      final mismatched = memory(id: memoryA.id, storyId: 'story-2');
      final repository = FakeMemoryRepository()..updateResult = mismatched;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(memoryA.id).future);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(editMemoryProvider(memoryA.id).future);

      final result = await container
          .read(editMemoryProvider(memoryA.id).notifier)
          .save(updateInput());

      final value = container.read(editMemoryProvider(memoryA.id));
      expect(result, isNull);
      expect(value, isA<AsyncError<EditMemoryState>>());
      expect(value.error, isA<StateError>());
      expect(value.error.toString(), isNot(contains(defaultStoryId)));
      expect(value.error.toString(), isNot(contains('story-2')));
      expect(readMemoryDetails(container, memoryA.id), same(memoryA));
      expect(readStoryMemories(container), <Memory>[memoryA]);
    });
  });
}

ProviderContainer createContainer(
  FakeMemoryRepository repository, {
  FakeStoryRepository? storyRepository,
}) {
  final container = ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWithValue(repository),
      storyRepositoryProvider.overrideWithValue(
        storyRepository ?? FakeStoryRepository(),
      ),
    ],
  );
  container.listen(
    editMemoryProvider(memoryA.id),
    (_, __) {},
    fireImmediately: true,
  );
  return container;
}

EditMemoryState readEditState(ProviderContainer container, String memoryId) {
  return container.read(editMemoryProvider(memoryId)).asData!.value;
}

Memory? readMemoryDetails(ProviderContainer container, String memoryId) {
  return container.read(memoryDetailsProvider(memoryId)).asData!.value.memory;
}

List<Memory> readStoryMemories(ProviderContainer container) {
  return container
      .read(storyMemoriesProvider(defaultStoryId))
      .asData!
      .value
      .memories;
}

List<UserStory> readStories(ProviderContainer container) {
  return container.read(storiesNotifierProvider).asData!.value.stories;
}

UpdateMemoryInput updateInput({
  String? memoryId,
  String title = 'Updated title',
}) {
  return UpdateMemoryInput(
    memoryId: memoryId ?? memoryA.id,
    title: MemoryUpdateField<String>.provided(title),
  );
}

Memory memory({
  String id = '00000000-0000-0000-0000-000000000001',
  String storyId = defaultStoryId,
  String createdBy = 'author-id',
  String title = 'First picnic',
  String? description = 'Near the river',
  String? placeName = 'Riverside Park',
  int day = 9,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: 41.715123, longitude: 44.827456),
    eventDate: MemoryDate(year: 2026, month: 8, day: day),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

const String defaultStoryId = 'story-id';
final Memory memoryA = memory(
  id: '00000000-0000-0000-0000-000000000001',
  title: 'A',
);
final Memory memoryB = memory(
  id: '00000000-0000-0000-0000-000000000002',
  title: 'B',
);
final Memory memoryC = memory(
  id: '00000000-0000-0000-0000-000000000003',
  title: 'C',
  day: 30,
);

UserStory userStory({
  int memoryCount = 0,
  int participantCount = 1,
}) {
  return UserStory(
    story: Story(
      id: defaultStoryId,
      title: 'Story title',
      description: 'Story description',
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 2),
    ),
    role: StoryRole.owner,
    memoryCount: memoryCount,
    participantCount: participantCount,
  );
}

final UserStory ownerStory = userStory();

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Completer<Memory>? updateCompleter;
  UpdateMemoryInput? receivedUpdateInput;
  List<Memory> memoriesResult = <Memory>[memoryA];
  Memory memoryResult = memoryA;
  Memory updateResult = memory(id: memoryA.id, title: 'Updated');
  Object? updateFailure;
  final List<String> operations = <String>[];

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    operations.add('getMemories');

    return memoriesResult.map(MemoryReadModel.fromMemory).toList();
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    operations.add('getMemory');

    return MemoryReadModel.fromMemory(memoryResult);
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
    operations.add('createMemory');

    return memoryResult;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    receivedUpdateInput = input;
    operations.add('updateMemory');

    final completer = updateCompleter;
    if (completer != null) {
      updateCompleter = null;
      return completer.future;
    }

    final failure = updateFailure;
    if (failure != null) {
      throw failure;
    }

    return updateResult;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
    operations.add('deleteMemory');
  }
}

final class FakeStoryRepository implements StoryRepository {
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  List<UserStory> storiesResult = <UserStory>[];
  UserStory storyResult = ownerStory;

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
    return storyResult;
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    return storiesResult;
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    throw UnimplementedError();
  }
}

final class UnexpectedMemoryException implements Exception {
  const UnexpectedMemoryException();
}
