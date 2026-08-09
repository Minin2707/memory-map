import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/default_memory_repository.dart';
import 'package:memory_map/features/memory/data/remote/dio_memory_remote_data_source.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return DefaultMemoryRepository(
    memoryRemoteDataSource: ref.watch(memoryRemoteDataSourceProvider),
  );
});
