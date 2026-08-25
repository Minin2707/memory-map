import 'dart:math';

import 'package:memory_map/features/map/domain/map_coordinate.dart';

const Duration playbackCinematicOpeningDuration =
    Duration(milliseconds: 2000);

final class PlaybackPolicy {
  const PlaybackPolicy({
    this.presentationDuration = const Duration(seconds: 5),
    Duration cameraDuration = const Duration(milliseconds: 2500),
    this.maximumCameraDuration = const Duration(seconds: 7),
    this.cameraDistanceScale = const Duration(milliseconds: 250),
    this.cinematicOpeningDuration = playbackCinematicOpeningDuration,
    this.arrivalPauseDuration = const Duration(milliseconds: 300),
    this.memoryRevealDuration = const Duration(milliseconds: 600),
    this.memoryDismissalDuration = const Duration(milliseconds: 420),
  }) : minimumCameraDuration = cameraDuration;

  final Duration presentationDuration;
  final Duration minimumCameraDuration;
  final Duration maximumCameraDuration;
  final Duration cameraDistanceScale;
  final Duration cinematicOpeningDuration;
  final Duration arrivalPauseDuration;
  final Duration memoryRevealDuration;
  final Duration memoryDismissalDuration;

  Duration get cameraDuration => minimumCameraDuration;

  Duration cameraDurationFor({
    required MapCoordinate? from,
    required MapCoordinate to,
  }) {
    final minimumDuration = minimumCameraDuration.compareTo(Duration.zero) <= 0
        ? const Duration(milliseconds: 2500)
        : minimumCameraDuration;
    final maximumDuration = maximumCameraDuration.compareTo(minimumDuration) < 0
        ? minimumDuration
        : maximumCameraDuration;
    if (from == null || from == to) {
      return minimumDuration;
    }

    final distanceKilometers = _distanceKilometers(from, to);
    final additionalMilliseconds = sqrt(distanceKilometers) *
        cameraDistanceScale.inMilliseconds.toDouble();
    final duration = minimumDuration +
        Duration(milliseconds: additionalMilliseconds.round());

    if (duration.compareTo(minimumDuration) < 0) {
      return minimumDuration;
    }

    if (duration.compareTo(maximumDuration) > 0) {
      return maximumDuration;
    }

    return duration;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackPolicy &&
            presentationDuration == other.presentationDuration &&
            minimumCameraDuration == other.minimumCameraDuration &&
            maximumCameraDuration == other.maximumCameraDuration &&
            cameraDistanceScale == other.cameraDistanceScale &&
            cinematicOpeningDuration == other.cinematicOpeningDuration &&
            arrivalPauseDuration == other.arrivalPauseDuration &&
            memoryRevealDuration == other.memoryRevealDuration &&
            memoryDismissalDuration == other.memoryDismissalDuration;
  }

  @override
  int get hashCode => Object.hash(
        presentationDuration,
        minimumCameraDuration,
        maximumCameraDuration,
        cameraDistanceScale,
        cinematicOpeningDuration,
        arrivalPauseDuration,
        memoryRevealDuration,
        memoryDismissalDuration,
      );

  @override
  String toString() {
    return 'PlaybackPolicy(presentationDuration: $presentationDuration, '
        'minimumCameraDuration: $minimumCameraDuration, '
        'maximumCameraDuration: $maximumCameraDuration, '
        'cinematicOpeningDuration: $cinematicOpeningDuration, '
        'arrivalPauseDuration: $arrivalPauseDuration, '
        'memoryRevealDuration: $memoryRevealDuration, '
        'memoryDismissalDuration: $memoryDismissalDuration)';
  }
}

double _distanceKilometers(MapCoordinate from, MapCoordinate to) {
  const earthRadiusKilometers = 6371.0;
  final fromLatitude = _degreesToRadians(from.latitude);
  final toLatitude = _degreesToRadians(to.latitude);
  final latitudeDelta = _degreesToRadians(to.latitude - from.latitude);
  final longitudeDelta = _degreesToRadians(to.longitude - from.longitude);

  final haversine = sin(latitudeDelta / 2) * sin(latitudeDelta / 2) +
      cos(fromLatitude) *
          cos(toLatitude) *
          sin(longitudeDelta / 2) *
          sin(longitudeDelta / 2);
  final safeHaversine = haversine.clamp(0.0, 1.0).toDouble();
  final centralAngle = 2 * atan2(
    sqrt(safeHaversine),
    sqrt(1 - safeHaversine),
  );

  return earthRadiusKilometers * centralAngle;
}

double _degreesToRadians(double degrees) {
  return degrees * pi / 180;
}
