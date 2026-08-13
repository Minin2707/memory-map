import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';

final class MemoryReadModel {
  const MemoryReadModel({
    required this.memory,
    this.previewPhoto,
  });

  factory MemoryReadModel.fromMemory(Memory memory) {
    return MemoryReadModel(memory: memory);
  }

  final Memory memory;
  final MemoryPhotoPreview? previewPhoto;

  bool get hasPreviewPhoto => previewPhoto != null;

  MemoryReadModel withMemoryMutation(Memory updatedMemory) {
    if (updatedMemory.id != memory.id) {
      throw ArgumentError('updatedMemory id must match memory id');
    }

    return MemoryReadModel(
      memory: updatedMemory,
      previewPhoto: previewPhoto,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryReadModel &&
            memory == other.memory &&
            previewPhoto == other.previewPhoto;
  }

  @override
  int get hashCode => Object.hash(memory, previewPhoto);

  @override
  String toString() {
    return 'MemoryReadModel(hasPreviewPhoto: $hasPreviewPhoto)';
  }
}
