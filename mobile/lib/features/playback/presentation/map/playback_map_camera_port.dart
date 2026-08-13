import 'package:memory_map/features/map/domain/map_coordinate.dart';

abstract interface class PlaybackMapCameraPort {
  Future<void> moveTo({
    required MapCoordinate target,
    required double zoom,
    required Duration duration,
  });
}
