import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_camera.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';

void main() {
  group('MapCameraPadding', () {
    test('shouldCreateValidPadding', () {
      final padding = MapCameraPadding(
        left: 1,
        top: 2,
        right: 3,
        bottom: 4,
      );

      expect(padding.left, 1);
      expect(padding.top, 2);
      expect(padding.right, 3);
      expect(padding.bottom, 4);
    });

    test('shouldRejectInvalidPadding', () {
      expect(
        () => MapCameraPadding(left: -1, top: 0, right: 0, bottom: 0),
        throwsA(argumentErrorWithMessage('left must not be negative')),
      );
      expect(
        () => MapCameraPadding(left: 0, top: double.nan, right: 0, bottom: 0),
        throwsA(argumentErrorWithMessage('top must not be negative')),
      );
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = MapCameraPadding(left: 1, top: 2, right: 3, bottom: 4);
      final second = MapCameraPadding(left: 1, top: 2, right: 3, bottom: 4);
      final different = MapCameraPadding(left: 4, top: 3, right: 2, bottom: 1);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
      expect(first.toString(), 'MapCameraPadding(configured: true)');
    });
  });

  group('MapCameraTarget', () {
    test('shouldCreateNeutralPointAndBoundsTargets', () {
      final neutral = MapCameraTarget.neutral();
      final point = MapCameraTarget.point(
        coordinate: coordinateA,
        zoom: 12,
      );
      final bounds = MapCameraTarget.bounds(
        southwest: coordinateB,
        northeast: coordinateA,
      );

      expect(neutral.type, MapCameraTargetType.neutral);
      expect(point.coordinate, coordinateA);
      expect(bounds.southwest, coordinateB);
      expect(bounds.northeast, coordinateA);
    });

    test('shouldRejectInvalidTargets', () {
      expect(
        () => MapCameraTarget.neutral(zoom: -1),
        throwsA(argumentErrorWithMessage('zoom must not be negative')),
      );
      expect(
        () => MapCameraTarget.point(
          coordinate: coordinateA,
          zoom: double.nan,
        ),
        throwsA(argumentErrorWithMessage('zoom must not be negative')),
      );
      expect(
        () => MapCameraTarget.bounds(
          southwest: coordinateA,
          northeast: coordinateB,
        ),
        throwsA(
          argumentErrorWithMessage(
            'southwest latitude must not exceed northeast',
          ),
        ),
      );
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = MapCameraTarget.point(coordinate: coordinateA, zoom: 12);
      final second = MapCameraTarget.point(coordinate: coordinateA, zoom: 12);
      final different = MapCameraTarget.point(coordinate: coordinateA, zoom: 8);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));

      final text = first.toString();
      expect(text, contains('MapCameraTarget'));
      expect(text, isNot(contains('41.7151')));
      expect(text, isNot(contains('44.8271')));
    });
  });

  group('MapCameraCommand', () {
    test('shouldCreateCommandAndRejectInvalidRevision', () {
      final target = MapCameraTarget.neutral();
      final command = MapCameraCommand(revision: 1, target: target);

      expect(command.revision, 1);
      expect(command.target, same(target));
      expect(
        () => MapCameraCommand(revision: -1, target: target),
        throwsA(argumentErrorWithMessage('revision must not be negative')),
      );
    });

    test('shouldUseValueEqualityHashCodeAndSafeToString', () {
      final first = MapCameraCommand(
        revision: 1,
        target: MapCameraTarget.point(coordinate: coordinateA, zoom: 12),
      );
      final second = MapCameraCommand(
        revision: 1,
        target: MapCameraTarget.point(coordinate: coordinateA, zoom: 12),
      );
      final different = MapCameraCommand(
        revision: 2,
        target: MapCameraTarget.point(coordinate: coordinateA, zoom: 12),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));

      final text = first.toString();
      expect(text, contains('revision: 1'));
      expect(text, isNot(contains('41.7151')));
      expect(text, isNot(contains('44.8271')));
    });
  });
}

final MapCoordinate coordinateA = MapCoordinate(
  latitude: 41.7151,
  longitude: 44.8271,
);

final MapCoordinate coordinateB = MapCoordinate(
  latitude: -12.0464,
  longitude: -77.0428,
);

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
