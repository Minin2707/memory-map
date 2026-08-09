import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';

void main() {
  group('MemoryLocation', () {
    test('shouldCreateLocation', () {
      final location = MemoryLocation(
        latitude: 41.715123,
        longitude: 44.827456,
      );

      expect(location.latitude, 41.715123);
      expect(location.longitude, 44.827456);
    });

    test('shouldAllowCoordinateBoundaries', () {
      expect(MemoryLocation(latitude: -90.0, longitude: -180.0), isNotNull);
      expect(MemoryLocation(latitude: 90.0, longitude: 180.0), isNotNull);
    });

    test('shouldRejectInvalidLatitude', () {
      for (final latitude in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -90.1,
        90.1,
      ]) {
        expect(
          () => MemoryLocation(latitude: latitude, longitude: 44.8),
          throwsA(argumentErrorWithMessage('latitude must be between -90 and 90')),
          reason: latitude.toString(),
        );
      }
    });

    test('shouldRejectInvalidLongitude', () {
      for (final longitude in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -180.1,
        180.1,
      ]) {
        expect(
          () => MemoryLocation(latitude: 41.7, longitude: longitude),
          throwsA(
            argumentErrorWithMessage('longitude must be between -180 and 180'),
          ),
          reason: longitude.toString(),
        );
      }
    });

    test('shouldNotSwapCoordinates', () {
      final location = MemoryLocation(
        latitude: 41.715123,
        longitude: 44.827456,
      );

      expect(location.latitude, 41.715123);
      expect(location.longitude, 44.827456);
    });

    test('shouldCompareLocationsByExactValue', () {
      final first = MemoryLocation(latitude: 41.715123, longitude: 44.827456);
      final second = MemoryLocation(latitude: 41.715123, longitude: 44.827456);
      final different = MemoryLocation(latitude: 41.715124, longitude: 44.827456);

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final location = MemoryLocation(
        latitude: 41.715123,
        longitude: 44.827456,
      );

      expect(location.toString(), 'MemoryLocation');
      expect(location.toString(), isNot(contains('41.715123')));
      expect(location.toString(), isNot(contains('44.827456')));
      expect(location.toString(), isNot(contains('latitude')));
      expect(location.toString(), isNot(contains('longitude')));
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
