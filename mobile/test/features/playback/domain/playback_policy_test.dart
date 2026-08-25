import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/playback/domain/playback_policy.dart';

void main() {
  group('PlaybackPolicy', () {
    test('shouldExposeMvpDurationsAndCameraBounds', () {
      const policy = PlaybackPolicy();

      expect(policy.presentationDuration, const Duration(seconds: 5));
      expect(policy.cameraDuration, const Duration(milliseconds: 2500));
      expect(policy.minimumCameraDuration, const Duration(milliseconds: 2500));
      expect(policy.maximumCameraDuration, const Duration(seconds: 7));
      expect(policy.cameraDistanceScale, const Duration(milliseconds: 250));
      expect(
        policy.cinematicOpeningDuration,
        const Duration(milliseconds: 2000),
      );
      expect(policy.arrivalPauseDuration, const Duration(milliseconds: 300));
      expect(policy.memoryRevealDuration, const Duration(milliseconds: 600));
      expect(policy.memoryDismissalDuration, const Duration(milliseconds: 420));
    });

    test('shouldUseMinimumCameraDurationWhenNoOriginExists', () {
      const policy = PlaybackPolicy();

      expect(
        policy.cameraDurationFor(from: null, to: coordinate(0, 0)),
        const Duration(milliseconds: 2500),
      );
    });

    test('shouldScaleCameraDurationByDistanceWithinBounds', () {
      const policy = PlaybackPolicy();

      final short = policy.cameraDurationFor(
        from: coordinate(0, 0),
        to: coordinate(0.01, 0),
      );
      final medium = policy.cameraDurationFor(
        from: coordinate(0, 0),
        to: coordinate(0, 0.9),
      );
      final large = policy.cameraDurationFor(
        from: coordinate(0, 0),
        to: coordinate(0, 90),
      );

      expect(short, greaterThanOrEqualTo(const Duration(milliseconds: 2500)));
      expect(short, lessThan(const Duration(seconds: 3)));
      expect(medium, greaterThan(const Duration(seconds: 4)));
      expect(medium, lessThan(const Duration(seconds: 6)));
      expect(large, const Duration(seconds: 7));
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      const first = PlaybackPolicy();
      const second = PlaybackPolicy();
      const different = PlaybackPolicy(
        presentationDuration: Duration(seconds: 6),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
      expect(first.toString(), contains('0:00:05.000000'));
      expect(first.toString(), contains('0:00:02.500000'));
      expect(first.toString(), contains('0:00:07.000000'));
      expect(first.toString(), contains('0:00:02.000000'));
      expect(first.toString(), contains('0:00:00.300000'));
      expect(first.toString(), contains('0:00:00.600000'));
      expect(first.toString(), contains('0:00:00.420000'));
    });
  });
}

MapCoordinate coordinate(double latitude, double longitude) {
  return MapCoordinate(latitude: latitude, longitude: longitude);
}
