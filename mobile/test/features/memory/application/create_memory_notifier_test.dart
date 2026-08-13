import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/create_memory_notifier.dart';
import 'package:memory_map/features/memory/application/create_memory_state.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('CreateMemoryNotifier startup', () {
    test('shouldStartIdleWithoutRepositoryCall', () async {
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);

      final state = await container.read(
        createMemoryProvider(defaultStoryId).future,
      );

      expect(state, const CreateMemoryState());
      expect(repository.createMemoryCalls, 0);
      expect(repository.getMemoriesCalls, 0);
    });
  });

  group('CreateMemoryNotifier submit', () {
    test('shouldSubmitInputReturnAuthoritativeMemoryAndResetState', () async {
      final repository = FakeMemoryRepository()
        ..createResult = authoritativeMemory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createMemoryProvider(defaultStoryId).future);

      final result = await container
          .read(createMemoryProvider(defaultStoryId).notifier)
          .submit(createInput());

      expect(result, same(authoritativeMemory));
      expect(repository.createMemoryCalls, 1);
      expect(repository.receivedCreateInput, createInput());
      expect(readCreateState(container), const CreateMemoryState());
      expect(repository.getMemoriesCalls, 0);
    });

    test('shouldExposeSubmittingWhileRepositoryCallIsPending', () async {
      final completer = Completer<Memory>();
      final repository = FakeMemoryRepository()..createCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createMemoryProvider(defaultStoryId).future);

      final submit = container
          .read(createMemoryProvider(defaultStoryId).notifier)
          .submit(createInput());
      await pumpEventQueue();

      expect(readCreateState(container).isSubmitting, isTrue);
      expect(readCreateState(container).failure, isNull);

      completer.complete(authoritativeMemory);
      await submit;
      expect(readCreateState(container).isSubmitting, isFalse);
    });

    test('shouldIgnoreDuplicateSubmitWhileSubmitting', () async {
      final completer = Completer<Memory>();
      final repository = FakeMemoryRepository()..createCompleter = completer;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createMemoryProvider(defaultStoryId).future);
      final notifier = container.read(
        createMemoryProvider(defaultStoryId).notifier,
      );

      final firstSubmit = notifier.submit(createInput());
      await pumpEventQueue();
      final secondResult = await notifier.submit(createInput(title: 'Second'));

      expect(secondResult, isNull);
      expect(repository.createMemoryCalls, 1);
      expect(readCreateState(container).isSubmitting, isTrue);

      completer.complete(authoritativeMemory);
      await firstSubmit;
    });

    test('shouldRejectMismatchedInputStoryIdWithoutRepositoryCall', () async {
      final repository = FakeMemoryRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createMemoryProvider(defaultStoryId).future);

      final result = await container
          .read(createMemoryProvider(defaultStoryId).notifier)
          .submit(createInput(storyId: 'story-2'));

      expect(result, isNull);
      expect(repository.createMemoryCalls, 0);
      expect(readCreateState(container).isSubmitting, isFalse);
      expect(
        readCreateState(container).failure,
        const MemoryValidationFailure(),
      );
    });

    test('shouldExposeKnownFailureAndSkipStoryMemoriesSync', () async {
      final repository = FakeMemoryRepository()
        ..createFailure = const MemoryApplicationException(
          MemoryCreationUnavailable(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createMemoryProvider(defaultStoryId).future);

      final result = await container
          .read(createMemoryProvider(defaultStoryId).notifier)
          .submit(createInput());

      expect(result, isNull);
      expect(repository.createMemoryCalls, 1);
      expect(repository.getMemoriesCalls, 0);
      expect(readCreateState(container).isSubmitting, isFalse);
      expect(
        readCreateState(container).failure,
        const MemoryCreationUnavailable(),
      );
    });

    test('shouldExposeUnexpectedFailureAsAsyncErrorAndResetSubmitting',
        () async {
      final repository = FakeMemoryRepository()
        ..createFailure = const UnexpectedMemoryException();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createMemoryProvider(defaultStoryId).future);

      final result = await container
          .read(createMemoryProvider(defaultStoryId).notifier)
          .submit(createInput());

      final value = container.read(createMemoryProvider(defaultStoryId));
      expect(result, isNull);
      expect(value, isA<AsyncError<CreateMemoryState>>());
      expect(value.error, isA<UnexpectedMemoryException>());
    });

    test('shouldClearOldFailureBeforeRetryAndReturnSuccess', () async {
      final completer = Completer<Memory>();
      final repository = FakeMemoryRepository()
        ..createFailure = const MemoryApplicationException(
          MemoryNetworkUnavailable(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createMemoryProvider(defaultStoryId).future);
      final notifier = container.read(
        createMemoryProvider(defaultStoryId).notifier,
      );
      await notifier.submit(createInput());

      repository
        ..createFailure = null
        ..createCompleter = completer;
      final submit = notifier.submit(createInput(title: 'Retry title'));
      await pumpEventQueue();

      expect(readCreateState(container).failure, isNull);
      expect(readCreateState(container).isSubmitting, isTrue);

      completer.complete(authoritativeMemory);
      expect(await submit, authoritativeMemory);
      expect(readCreateState(container), const CreateMemoryState());
    });

    test('shouldTreatAuthoritativeStoryMismatchAsUnexpectedAndSkipSync',
        () async {
      final mismatchedMemory = memory(storyId: 'story-2');
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA]
        ..createResult = mismatchedMemory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(createMemoryProvider(defaultStoryId).future);

      final result = await container
          .read(createMemoryProvider(defaultStoryId).notifier)
          .submit(createInput());

      final value = container.read(createMemoryProvider(defaultStoryId));
      expect(result, isNull);
      expect(value, isA<AsyncError<CreateMemoryState>>());
      expect(value.error, isA<StateError>());
      expect(value.error.toString(), isNot(contains(defaultStoryId)));
      expect(value.error.toString(), isNot(contains('story-2')));
      expect(readStoryMemories(container), <Memory>[memoryA]);
    });
  });

  group('CreateMemoryNotifier StoryMemories sync', () {
    test('shouldUpsertAuthoritativeMemoryIntoLoadedStoryMemories', () async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA, memoryC]
        ..createResult = memoryB;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(createMemoryProvider(defaultStoryId).future);

      final result = await container
          .read(createMemoryProvider(defaultStoryId).notifier)
          .submit(createInput());

      expect(result, same(memoryB));
      expect(readStoryMemories(container), <Memory>[memoryA, memoryB, memoryC]);
      expect(repository.operations, <String>['getMemories', 'createMemory']);
    });

    test('shouldNotForceLoadStoryMemoriesWhenListProviderDoesNotExist',
        () async {
      final repository = FakeMemoryRepository()
        ..createResult = authoritativeMemory;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createMemoryProvider(defaultStoryId).future);

      final result = await container
          .read(createMemoryProvider(defaultStoryId).notifier)
          .submit(createInput());

      expect(result, same(authoritativeMemory));
      expect(repository.createMemoryCalls, 1);
      expect(repository.getMemoriesCalls, 0);
      expect(repository.operations, <String>['createMemory']);
    });

    test('shouldReconcileLoadedStorySummaryAfterCreate', () async {
      final memoryRepository = FakeMemoryRepository()..createResult = memoryB;
      final storyRepository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory]
        ..storyResult = userStory(memoryCount: 2);
      final container = createContainer(
        memoryRepository,
        storyRepository: storyRepository,
      );
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);
      await container.read(createMemoryProvider(defaultStoryId).future);

      final result = await container
          .read(createMemoryProvider(defaultStoryId).notifier)
          .submit(createInput());

      expect(result, same(memoryB));
      expect(storyRepository.getStoriesCalls, 1);
      expect(storyRepository.getStoryCalls, 1);
      expect(readStories(container).single.memoryCount, 2);
    });

    test('shouldResetToIdle', () async {
      final repository = FakeMemoryRepository()
        ..createFailure = const MemoryApplicationException(
          MemoryRequestTimedOut(),
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(createMemoryProvider(defaultStoryId).future);
      final notifier = container.read(
        createMemoryProvider(defaultStoryId).notifier,
      );
      await notifier.submit(createInput());

      notifier.reset();

      expect(readCreateState(container), const CreateMemoryState());
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
    createMemoryProvider(defaultStoryId),
    (_, __) {},
    fireImmediately: true,
  );
  return container;
}

CreateMemoryState readCreateState(ProviderContainer container) {
  return container.read(createMemoryProvider(defaultStoryId)).asData!.value;
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

CreateMemoryInput createInput({
  String storyId = defaultStoryId,
  String title = 'First day in Tbilisi',
  String? description = 'Old city walk',
  String? placeName = 'Tbilisi',
  MemoryLocation? location,
  MemoryDate? eventDate,
}) {
  return CreateMemoryInput(
    storyId: storyId,
    title: title,
    description: description,
    placeName: placeName,
    location: location ?? MemoryLocation(latitude: 41.6938, longitude: 44.8015),
    eventDate: eventDate ?? MemoryDate(year: 2024, month: 5, day: 18),
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
  int createdHour = 10,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: 2026, month: 8, day: day),
    createdAt: DateTime.utc(2026, 8, 9, createdHour),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

const String defaultStoryId = 'story-id';

final Memory memoryA = memory(
  id: '00000000-0000-0000-0000-000000000001',
  title: 'A',
  day: 10,
);
final Memory memoryB = memory(
  id: '00000000-0000-0000-0000-000000000002',
  title: 'B',
  day: 15,
);
final Memory memoryC = memory(
  id: '00000000-0000-0000-0000-000000000003',
  title: 'C',
  day: 20,
);
final Memory authoritativeMemory = memory(
  id: '00000000-0000-0000-0000-000000000099',
  title: 'Server title',
  description: 'Server description',
  placeName: 'Server place',
  day: 17,
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
  Completer<Memory>? createCompleter;
  CreateMemoryInput? receivedCreateInput;
  List<Memory> memoriesResult = <Memory>[];
  Memory createResult = authoritativeMemory;
  Object? createFailure;
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

    return MemoryReadModel.fromMemory(memoryA);
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
    receivedCreateInput = input;
    operations.add('createMemory');

    final completer = createCompleter;
    if (completer != null) {
      createCompleter = null;
      return completer.future;
    }

    final failure = createFailure;
    if (failure != null) {
      throw failure;
    }

    return createResult;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    operations.add('updateMemory');

    return memoryA;
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
