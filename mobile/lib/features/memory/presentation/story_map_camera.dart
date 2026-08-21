import 'package:memory_map/features/map/domain/map_camera.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';

const double storyMapNeutralZoom = 1.5;
const double storyMapSingleMarkerZoom = 12;

final MapCameraPadding storyMapBoundsPadding = MapCameraPadding(
  left: 56.0,
  top: 128.0,
  right: 78.0,
  bottom: 220.0,
);

MapCameraTarget storyMapCameraTargetForMarkers(List<MapMarker> markers) {
  if (markers.isEmpty) {
    return MapCameraTarget.neutral(zoom: storyMapNeutralZoom);
  }

  if (markers.length == 1 || _allMarkersShareCoordinate(markers)) {
    return MapCameraTarget.point(
      coordinate: markers.first.coordinate,
      zoom: storyMapSingleMarkerZoom,
    );
  }

  var minLatitude = markers.first.coordinate.latitude;
  var maxLatitude = markers.first.coordinate.latitude;
  var minLongitude = markers.first.coordinate.longitude;
  var maxLongitude = markers.first.coordinate.longitude;

  for (final marker in markers.skip(1)) {
    final coordinate = marker.coordinate;
    if (coordinate.latitude < minLatitude) {
      minLatitude = coordinate.latitude;
    }
    if (coordinate.latitude > maxLatitude) {
      maxLatitude = coordinate.latitude;
    }
    if (coordinate.longitude < minLongitude) {
      minLongitude = coordinate.longitude;
    }
    if (coordinate.longitude > maxLongitude) {
      maxLongitude = coordinate.longitude;
    }
  }

  return MapCameraTarget.bounds(
    southwest: MapCoordinate(
      latitude: minLatitude,
      longitude: minLongitude,
    ),
    northeast: MapCoordinate(
      latitude: maxLatitude,
      longitude: maxLongitude,
    ),
    padding: storyMapBoundsPadding,
  );
}

bool _allMarkersShareCoordinate(List<MapMarker> markers) {
  final coordinate = markers.first.coordinate;

  for (final marker in markers.skip(1)) {
    if (marker.coordinate != coordinate) {
      return false;
    }
  }

  return true;
}
