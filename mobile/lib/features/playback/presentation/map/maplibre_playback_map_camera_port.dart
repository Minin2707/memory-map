import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_map.dart';
import 'package:memory_map/features/playback/presentation/map/playback_map_camera_port.dart';

final class MapLibrePlaybackMapCameraPort implements PlaybackMapCameraPort {
  MapLibrePlaybackMapCameraPort(this._controller);

  final MapLibreMapController _controller;

  @override
  Future<void> moveTo({
    required MapCoordinate target,
    required double zoom,
    required Duration duration,
  }) async {
    await _controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        mapLibreLatLngFromMapCoordinate(target),
        zoom,
      ),
      duration: duration,
    );
  }
}
