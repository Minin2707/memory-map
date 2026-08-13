import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory.dart';

Memory? findSelectedStoryMapMemory(
  List<Memory> memories,
  String? selectedMarkerId,
) {
  if (selectedMarkerId == null) {
    return null;
  }

  for (final memory in memories) {
    if (memory.id == selectedMarkerId) {
      return memory;
    }
  }

  return null;
}

MemoryReadModel? findSelectedStoryMapMemoryReadModel(
  List<MemoryReadModel> memories,
  String? selectedMarkerId,
) {
  if (selectedMarkerId == null) {
    return null;
  }

  for (final memory in memories) {
    if (memory.memory.id == selectedMarkerId) {
      return memory;
    }
  }

  return null;
}
