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
