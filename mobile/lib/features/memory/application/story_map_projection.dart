import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/memory/domain/memory.dart';

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
