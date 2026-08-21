import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

final class StoryMapMarkerPresentation {
  const StoryMapMarkerPresentation({
    required this.marker,
    this.previewPhoto,
  });

  final MapMarker marker;
  final MemoryPhotoPreview? previewPhoto;

  bool get hasPreviewPhoto => previewPhoto != null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryMapMarkerPresentation &&
            marker == other.marker &&
            previewPhoto == other.previewPhoto;
  }

  @override
  int get hashCode => Object.hash(marker, previewPhoto);

  @override
  String toString() {
    return 'StoryMapMarkerPresentation(hasPreviewPhoto: $hasPreviewPhoto)';
  }
}

MapMarker mapMarkerFromMemory(Memory memory) {
  return MapMarker(
    id: memory.id,
    coordinate: MapCoordinate(
      latitude: memory.location.latitude,
      longitude: memory.location.longitude,
    ),
  );
}

List<MapMarker> mapMarkersFromMemories(List<Memory> memories) {
  return List<MapMarker>.unmodifiable(
    memories.map(mapMarkerFromMemory),
  );
}

List<MapMarker> mapMarkersFromMemoryReadModels(
  List<MemoryReadModel> memories,
) {
  return List<MapMarker>.unmodifiable(
    memories.map((item) => mapMarkerFromMemory(item.memory)),
  );
}

StoryMapMarkerPresentation storyMapMarkerPresentationFromMemoryReadModel(
  MemoryReadModel memory,
) {
  return StoryMapMarkerPresentation(
    marker: mapMarkerFromMemory(memory.memory),
    previewPhoto: memory.previewPhoto,
  );
}

List<StoryMapMarkerPresentation> storyMapMarkerPresentationsFromMemoryReadModels(
  List<MemoryReadModel> memories,
) {
  return List<StoryMapMarkerPresentation>.unmodifiable(
    memories.map(storyMapMarkerPresentationFromMemoryReadModel),
  );
}
