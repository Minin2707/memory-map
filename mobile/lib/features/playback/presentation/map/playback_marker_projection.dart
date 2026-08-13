import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

final class PlaybackMapMarker {
  PlaybackMapMarker({
    required this.marker,
    required this.orderNumber,
    required this.hasPreviewPhoto,
  });

  final MapMarker marker;
  final int orderNumber;
  final bool hasPreviewPhoto;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackMapMarker &&
            marker == other.marker &&
            orderNumber == other.orderNumber &&
            hasPreviewPhoto == other.hasPreviewPhoto;
  }

  @override
  int get hashCode => Object.hash(marker, orderNumber, hasPreviewPhoto);

  @override
  String toString() {
    return 'PlaybackMapMarker(orderNumber: $orderNumber, '
        'hasPreviewPhoto: $hasPreviewPhoto)';
  }
}

List<PlaybackMapMarker> playbackMarkersFromSnapshot(
  List<MemoryReadModel> snapshot,
) {
  return List<PlaybackMapMarker>.unmodifiable(
    List<PlaybackMapMarker>.generate(snapshot.length, (index) {
      final readModel = snapshot[index];
      final memory = readModel.memory;
      return PlaybackMapMarker(
        marker: MapMarker(
          id: 'playback-marker-$index',
          coordinate: MapCoordinate(
            latitude: memory.location.latitude,
            longitude: memory.location.longitude,
          ),
        ),
        orderNumber: index + 1,
        hasPreviewPhoto: readModel.hasPreviewPhoto,
      );
    }),
  );
}

String? playbackCurrentMarkerId(
  List<PlaybackMapMarker> markers,
  int? currentIndex,
) {
  if (currentIndex == null ||
      currentIndex < 0 ||
      currentIndex >= markers.length) {
    return null;
  }

  return markers[currentIndex].marker.id;
}
