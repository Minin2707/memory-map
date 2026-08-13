import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

abstract interface class MemoryRemoteDataSource {
  Future<List<MemoryReadModel>> getMemories(String storyId);

  Future<MemoryReadModel> getMemory(String memoryId);

  Future<Memory> createMemory(CreateMemoryInput input);

  Future<Memory> updateMemory(UpdateMemoryInput input);

  Future<void> deleteMemory(DeleteMemoryInput input);
}
