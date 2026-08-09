import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/default_memory_repository.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/data/remote/memory_remote_data_source.dart';
import 'package:memory_map/features/memory/data/remote/memory_remote_exception.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

void main() {
  group('DefaultMemoryRepository getMemories', () {
    test('shouldForwardExactStoryId', () async {
      final fakes = MemoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.getMemories(' story-id ');

      expect(fakes.remote.getMemoriesCalls, 1);
      expect(fakes.remote.getMemoryCalls, 0);
      expect(fakes.remote.createMemoryCalls, 0);
      expect(fakes.remote.updateMemoryCalls, 0);
      expect(fakes.remote.deleteMemoryCalls, 0);
      expect(fakes.remote.receivedStoryId, ' story-id ');
    });

    test('shouldReturnExactOrderedMemoryListWithoutSorting', () async {
      final memories = <Memory>[
        memoryFixture(id: 'memory-c', title: 'C', day: 20),
        memoryFixture(id: 'memory-a', title: 'A', day: 10),
        memoryFixture(id: 'memory-b', title: 'B', day: 15),
      ];
      final fakes = MemoryRepositoryFakes()..remote.memories = memories;
      final repository = fakes.createRepository();

      final result = await repository.getMemories('story-id');

      expect(result, same(memories));
      expect(result.map((memory) => memory.id), <String>[
        'memory-c',
        'memory-a',
        'memory-b',
      ]);
    });

    test('shouldReturnEmptyMemoryList', () async {
      final memories = <Memory>[];
      final fakes = MemoryRepositoryFakes()..remote.memories = memories;
      final repository = fakes.createRepository();

      final result = await repository.getMemories('story-id');

      expect(result, same(memories));
      expect(result, isEmpty);
    });
  });

  group('DefaultMemoryRepository getMemory', () {
    test('shouldForwardExactMemoryId', () async {
      final fakes = MemoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.getMemory(' memory-id ');

      expect(fakes.remote.getMemoryCalls, 1);
      expect(fakes.remote.receivedMemoryId, ' memory-id ');
    });

    test('shouldReturnExactAuthoritativeMemory', () async {
      final memory = memoryFixture(id: 'server-memory-id', title: 'Server');
      final fakes = MemoryRepositoryFakes()..remote.memory = memory;
      final repository = fakes.createRepository();

      final result = await repository.getMemory('memory-id');

      expect(result, same(memory));
    });
  });

  group('DefaultMemoryRepository createMemory', () {
    test('shouldForwardExactCreateInput', () async {
      final fakes = MemoryRepositoryFakes();
      final repository = fakes.createRepository();
      final input = createInput(
        storyId: ' story-id ',
        title: ' Client title ',
      );

      await repository.createMemory(input);

      expect(fakes.remote.createMemoryCalls, 1);
      expect(fakes.remote.receivedCreateInput, same(input));
    });

    test('shouldReturnExactRemoteMemoryWithoutSynthesizingFields', () async {
      final serverMemory = memoryFixture(
        id: 'server-memory-id',
        createdBy: 'server-user-id',
        title: 'Server title',
        updatedHour: 23,
      );
      final fakes = MemoryRepositoryFakes()..remote.memory = serverMemory;
      final repository = fakes.createRepository();

      final result = await repository.createMemory(
        createInput(title: 'Client title'),
      );

      expect(result, same(serverMemory));
      expect(result.id, 'server-memory-id');
      expect(result.createdBy, 'server-user-id');
      expect(result.title, 'Server title');
      expect(result.updatedAt, DateTime.utc(2026, 8, 9, 23));
    });
  });

  group('DefaultMemoryRepository updateMemory', () {
    test('shouldForwardExactUpdateInput', () async {
      final fakes = MemoryRepositoryFakes();
      final repository = fakes.createRepository();
      final input = updateInput(
        memoryId: ' memory-id ',
        title: ' Client title ',
      );

      await repository.updateMemory(input);

      expect(fakes.remote.updateMemoryCalls, 1);
      expect(fakes.remote.receivedUpdateInput, same(input));
    });

    test('shouldReturnExactRemoteMemoryWithoutLocalMerge', () async {
      final serverMemory = memoryFixture(title: 'Server title');
      final fakes = MemoryRepositoryFakes()..remote.memory = serverMemory;
      final repository = fakes.createRepository();

      final result = await repository.updateMemory(
        updateInput(title: 'Client title'),
      );

      expect(result, same(serverMemory));
      expect(result.title, 'Server title');
    });
  });

  group('DefaultMemoryRepository deleteMemory', () {
    test('shouldForwardExactDeleteInputAndComplete', () async {
      final fakes = MemoryRepositoryFakes();
      final repository = fakes.createRepository();
      final input = DeleteMemoryInput(memoryId: ' memory-id ');

      await expectLater(repository.deleteMemory(input), completes);

      expect(fakes.remote.deleteMemoryCalls, 1);
      expect(fakes.remote.receivedDeleteInput, same(input));
      expect(fakes.remote.totalCalls, 1);
    });
  });

  group('DefaultMemoryRepository failure mapping', () {
    test('shouldMapKnownRemoteFailures', () async {
      final cases = remoteFailureCases();

      for (final failureCase in cases) {
        await expectRemoteFailure(
          failureCase.exception,
          failureCase.failure,
        );
      }
    });

    test('shouldMapMalformedResponseToUnknownMemoryFailure', () async {
      await expectRemoteFailure(
        const MemoryRemoteMalformedResponseException(),
        const UnknownMemoryFailure(),
      );
    });

    test('shouldMapUnknownRemoteExceptionToUnknownMemoryFailure', () async {
      await expectRemoteFailure(
        const MemoryRemoteUnknownException(),
        const UnknownMemoryFailure(),
      );
    });

    test('shouldNotMaskUnexpectedGetMemoriesException', () async {
      final fakes = MemoryRepositoryFakes()
        ..remote.failure = const UnexpectedMemoryException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.getMemories('story-id'),
        throwsA(isA<UnexpectedMemoryException>()),
      );
    });

    test('shouldNotMaskUnexpectedGetMemoryException', () async {
      final fakes = MemoryRepositoryFakes()
        ..remote.failure = const UnexpectedMemoryException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.getMemory('memory-id'),
        throwsA(isA<UnexpectedMemoryException>()),
      );
    });

    test('shouldNotMaskUnexpectedCreateException', () async {
      final fakes = MemoryRepositoryFakes()
        ..remote.failure = const UnexpectedMemoryException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.createMemory(createInput()),
        throwsA(isA<UnexpectedMemoryException>()),
      );
    });

    test('shouldNotMaskUnexpectedUpdateException', () async {
      final fakes = MemoryRepositoryFakes()
        ..remote.failure = const UnexpectedMemoryException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.updateMemory(updateInput()),
        throwsA(isA<UnexpectedMemoryException>()),
      );
    });

    test('shouldNotMaskUnexpectedDeleteException', () async {
      final fakes = MemoryRepositoryFakes()
        ..remote.failure = const UnexpectedMemoryException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.deleteMemory(DeleteMemoryInput(memoryId: 'memory-id')),
        throwsA(isA<UnexpectedMemoryException>()),
      );
    });

    test('shouldNotExposeSensitiveDetailsInApplicationException', () async {
      final fakes = MemoryRepositoryFakes()
        ..remote.failure = const MemoryRemoteNotFoundException();
      final repository = fakes.createRepository();

      try {
        await repository.getMemory('private-memory-id');
        fail('Expected memory application exception');
      } on MemoryApplicationException catch (error) {
        expect(error.toString(), 'MemoryApplicationException');
        expect(error.toString(), isNot(contains('private-memory-id')));
        expect(error.toString(), isNot(contains('private-story-id')));
        expect(error.toString(), isNot(contains('secret title')));
        expect(error.toString(), isNot(contains('secret description')));
        expect(error.toString(), isNot(contains('secret place')));
        expect(error.toString(), isNot(contains('55.751244')));
        expect(error.toString(), isNot(contains('37.618423')));
        expect(error.toString(), isNot(contains('2026-08-09')));
        expect(error.toString(), isNot(contains('token')));
        expect(error.toString(), isNot(contains('Dio')));
        expect(error.toString(), isNot(contains('MemoryRemote')));
        expect(error.toString(), isNot(contains('ProblemDetail')));
        expect(error.toString(), isNot(contains('HTTP')));
        expect(error.toString(), isNot(contains('404')));
      }
    });
  });

  group('DefaultMemoryRepository construction', () {
    test('shouldNotCallRemoteDuringConstruction', () {
      final fakes = MemoryRepositoryFakes();

      fakes.createRepository();

      expect(fakes.remote.totalCalls, 0);
    });
  });
}

Future<void> expectRemoteFailure(
  MemoryRemoteException exception,
  MemoryFailure failure,
) async {
  final fakes = MemoryRepositoryFakes()..remote.failure = exception;
  final repository = fakes.createRepository();

  await expectApplicationFailure(repository.getMemories('story-id'), failure);
}

Future<void> expectApplicationFailure(
  Future<Object?> future,
  MemoryFailure failure,
) async {
  await expectLater(
    future,
    throwsA(
      isA<MemoryApplicationException>().having(
        (exception) => exception.failure,
        'failure',
        failure,
      ),
    ),
  );
}

List<RemoteFailureCase> remoteFailureCases() {
  return const <RemoteFailureCase>[
    RemoteFailureCase(
      MemoryRemoteValidationException(),
      MemoryValidationFailure(),
    ),
    RemoteFailureCase(
      MemoryRemoteUnauthorizedException(),
      MemoryUnauthorized(),
    ),
    RemoteFailureCase(
      MemoryRemoteStoryUnavailableException(),
      MemoryStoryUnavailable(),
    ),
    RemoteFailureCase(
      MemoryRemoteNotFoundException(),
      MemoryNotFound(),
    ),
    RemoteFailureCase(
      MemoryRemoteCreationUnavailableException(),
      MemoryCreationUnavailable(),
    ),
    RemoteFailureCase(
      MemoryRemoteUpdateUnavailableException(),
      MemoryUpdateUnavailable(),
    ),
    RemoteFailureCase(
      MemoryRemoteDeletionUnavailableException(),
      MemoryDeletionUnavailable(),
    ),
    RemoteFailureCase(
      MemoryRemoteNetworkException(),
      MemoryNetworkUnavailable(),
    ),
    RemoteFailureCase(
      MemoryRemoteTimeoutException(),
      MemoryRequestTimedOut(),
    ),
    RemoteFailureCase(
      MemoryRemoteServerException(),
      MemoryServerFailure(),
    ),
    RemoteFailureCase(
      MemoryRemoteMalformedResponseException(),
      UnknownMemoryFailure(),
    ),
    RemoteFailureCase(
      MemoryRemoteUnknownException(),
      UnknownMemoryFailure(),
    ),
  ];
}

CreateMemoryInput createInput({
  String storyId = 'story-id',
  String title = 'Client title',
}) {
  return CreateMemoryInput(
    storyId: storyId,
    title: title,
    description: 'Client description',
    placeName: 'Client place',
    location: location(),
    eventDate: memoryDate(),
  );
}

UpdateMemoryInput updateInput({
  String memoryId = 'memory-id',
  String title = 'Client title',
}) {
  return UpdateMemoryInput(
    memoryId: memoryId,
    title: MemoryUpdateField<String>.provided(title),
    description: const MemoryUpdateField<String?>.provided(null),
  );
}

Memory memoryFixture({
  String id = 'memory-id',
  String storyId = 'story-id',
  String createdBy = 'author-id',
  String title = 'First picnic',
  int day = 9,
  int updatedHour = 11,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: 'Near the river',
    placeName: 'Riverside Park',
    location: location(),
    eventDate: memoryDate(day: day),
    createdAt: DateTime.utc(2026, 8, day, 10),
    updatedAt: DateTime.utc(2026, 8, day, updatedHour),
  );
}

MemoryLocation location() {
  return MemoryLocation(
    latitude: 55.751244,
    longitude: 37.618423,
  );
}

MemoryDate memoryDate({int day = 9}) {
  return MemoryDate(year: 2026, month: 8, day: day);
}

final class MemoryRepositoryFakes {
  late final FakeMemoryRemoteDataSource remote = FakeMemoryRemoteDataSource();

  DefaultMemoryRepository createRepository() {
    return DefaultMemoryRepository(memoryRemoteDataSource: remote);
  }
}

final class FakeMemoryRemoteDataSource implements MemoryRemoteDataSource {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Object? failure;
  String? receivedStoryId;
  String? receivedMemoryId;
  CreateMemoryInput? receivedCreateInput;
  UpdateMemoryInput? receivedUpdateInput;
  DeleteMemoryInput? receivedDeleteInput;
  List<Memory> memories = <Memory>[memoryFixture()];
  Memory memory = memoryFixture();

  int get totalCalls {
    return getMemoriesCalls +
        getMemoryCalls +
        createMemoryCalls +
        updateMemoryCalls +
        deleteMemoryCalls;
  }

  @override
  Future<List<Memory>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    receivedStoryId = storyId;
    _throwIfConfigured();

    return memories;
  }

  @override
  Future<Memory> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    receivedMemoryId = memoryId;
    _throwIfConfigured();

    return memory;
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
    receivedCreateInput = input;
    _throwIfConfigured();

    return memory;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    receivedUpdateInput = input;
    _throwIfConfigured();

    return memory;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
    receivedDeleteInput = input;
    _throwIfConfigured();
  }

  void _throwIfConfigured() {
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
  }
}

final class RemoteFailureCase {
  const RemoteFailureCase(this.exception, this.failure);

  final MemoryRemoteException exception;
  final MemoryFailure failure;
}

final class UnexpectedMemoryException implements Exception {
  const UnexpectedMemoryException();
}
