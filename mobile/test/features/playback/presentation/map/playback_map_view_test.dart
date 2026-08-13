import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/playback/domain/playback_camera_command.dart';
import 'package:memory_map/features/playback/presentation/map/playback_map_view.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_projection.dart';

void main() {
  group('PlaybackMapView interaction policy', () {
    test('shouldDisableManualMapGesturesForCameraControlledPlayback', () {
      expect(playbackMapInteractionPolicy.scrollGesturesEnabled, isFalse);
      expect(playbackMapInteractionPolicy.zoomGesturesEnabled, isFalse);
      expect(playbackMapInteractionPolicy.rotateGesturesEnabled, isFalse);
      expect(playbackMapInteractionPolicy.tiltGesturesEnabled, isFalse);
    });
  });

  group('PlaybackMapView callback contract', () {
    test('shouldRequireCameraArrivalAndFailureCallbacks', () {
      final view = PlaybackMapView(
        markers: const [],
        route: PlaybackRouteProjection(),
        currentIndex: null,
        cameraCommand: PlaybackCameraCommand(
          revision: 1,
          memoryIndex: 0,
          target: MapCoordinate(latitude: 41.7151, longitude: 44.8271),
          duration: const Duration(seconds: 2),
        ),
        onCameraArrived: (_) {},
        onCameraFailed: (_) {},
      );

      expect(view.onCameraArrived, isA<ValueChanged<int>>());
      expect(view.onCameraFailed, isA<ValueChanged<int>>());
      expect(view.route.hasRoute, isFalse);
    });
  });
}
