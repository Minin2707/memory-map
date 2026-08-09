import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/data/remote/memory_remote_data_source.dart';
import 'package:memory_map/features/memory/data/remote/memory_remote_exception.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

final class DefaultMemoryRepository implements MemoryRepository {
  const DefaultMemoryRepository({
    required MemoryRemoteDataSource memoryRemoteDataSource,
  }) : _memoryRemoteDataSource = memoryRemoteDataSource;

  final MemoryRemoteDataSource _memoryRemoteDataSource;

  @override
  Future<List<Memory>> getMemories(String storyId) async {
    try {
      return await _memoryRemoteDataSource.getMemories(storyId);
    } on MemoryRemoteException catch (exception) {
      throw MemoryApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<Memory> getMemory(String memoryId) async {
    try {
      return await _memoryRemoteDataSource.getMemory(memoryId);
    } on MemoryRemoteException catch (exception) {
      throw MemoryApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    try {
      return await _memoryRemoteDataSource.createMemory(input);
    } on MemoryRemoteException catch (exception) {
      throw MemoryApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    try {
      return await _memoryRemoteDataSource.updateMemory(input);
    } on MemoryRemoteException catch (exception) {
      throw MemoryApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    try {
      await _memoryRemoteDataSource.deleteMemory(input);
    } on MemoryRemoteException catch (exception) {
      throw MemoryApplicationException(_mapFailure(exception));
    }
  }

  MemoryFailure _mapFailure(MemoryRemoteException exception) {
    return switch (exception) {
      MemoryRemoteValidationException() => const MemoryValidationFailure(),
      MemoryRemoteUnauthorizedException() => const MemoryUnauthorized(),
      MemoryRemoteStoryUnavailableException() =>
        const MemoryStoryUnavailable(),
      MemoryRemoteNotFoundException() => const MemoryNotFound(),
      MemoryRemoteCreationUnavailableException() =>
        const MemoryCreationUnavailable(),
      MemoryRemoteUpdateUnavailableException() =>
        const MemoryUpdateUnavailable(),
      MemoryRemoteDeletionUnavailableException() =>
        const MemoryDeletionUnavailable(),
      MemoryRemoteNetworkException() => const MemoryNetworkUnavailable(),
      MemoryRemoteTimeoutException() => const MemoryRequestTimedOut(),
      MemoryRemoteServerException() => const MemoryServerFailure(),
      MemoryRemoteMalformedResponseException() =>
        const UnknownMemoryFailure(),
      MemoryRemoteUnknownException() => const UnknownMemoryFailure(),
    };
  }
}
