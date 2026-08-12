import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';

void main() {
  group('MapCoordinate', () {
    test('shouldCreateValidBoundaryCoordinates', () {
      final northWest = MapCoordinate(latitude: 90, longitude: -180);
      final southEast = MapCoordinate(latitude: -90, longitude: 180);

      expect(northWest.latitude, 90);
      expect(northWest.longitude, -180);
      expect(southEast.latitude, -90);
      expect(southEast.longitude, 180);
    });

    test('shouldRejectInvalidLatitude', () {
      expect(
        () => MapCoordinate(latitude: 90.1, longitude: 0),
        throwsA(argumentErrorWithMessage('latitude must be between -90 and 90')),
      );
      expect(
        () => MapCoordinate(latitude: -90.1, longitude: 0),
        throwsA(argumentErrorWithMessage('latitude must be between -90 and 90')),
      );
      expect(
        () => MapCoordinate(latitude: double.nan, longitude: 0),
        throwsA(argumentErrorWithMessage('latitude must be between -90 and 90')),
      );
      expect(
        () => MapCoordinate(latitude: double.infinity, longitude: 0),
        throwsA(argumentErrorWithMessage('latitude must be between -90 and 90')),
      );
    });

    test('shouldRejectInvalidLongitude', () {
      expect(
        () => MapCoordinate(latitude: 0, longitude: 180.1),
        throwsA(
          argumentErrorWithMessage('longitude must be between -180 and 180'),
        ),
      );
      expect(
        () => MapCoordinate(latitude: 0, longitude: -180.1),
        throwsA(
          argumentErrorWithMessage('longitude must be between -180 and 180'),
        ),
      );
      expect(
        () => MapCoordinate(latitude: 0, longitude: double.nan),
        throwsA(
          argumentErrorWithMessage('longitude must be between -180 and 180'),
        ),
      );
      expect(
        () => MapCoordinate(latitude: 0, longitude: double.negativeInfinity),
        throwsA(
          argumentErrorWithMessage('longitude must be between -180 and 180'),
        ),
      );
    });

    test('shouldUseValueEqualityAndHashCode', () {
      final first = MapCoordinate(latitude: 41.7151, longitude: 44.8271);
      final second = MapCoordinate(latitude: 41.7151, longitude: 44.8271);
      final different = MapCoordinate(latitude: 40, longitude: 44.8271);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('shouldHaveSafeToString', () {
      final coordinate = MapCoordinate(latitude: 41.7151, longitude: 44.8271);

      final text = coordinate.toString();

      expect(text, 'MapCoordinate');
      expect(text, isNot(contains('41.7151')));
      expect(text, isNot(contains('44.8271')));
      expect(text, isNot(contains('latitude')));
      expect(text, isNot(contains('longitude')));
    });
  });
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
