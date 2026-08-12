import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';

void main() {
  group('MapMarker', () {
    test('shouldCreateValidMarker', () {
      final coordinate = MapCoordinate(latitude: 41.7151, longitude: 44.8271);
      final marker = MapMarker(id: 'memory-1', coordinate: coordinate);

      expect(marker.id, 'memory-1');
      expect(marker.coordinate, same(coordinate));
    });

    test('shouldRejectBlankId', () {
      expect(
        () => MapMarker(id: '', coordinate: validCoordinate),
        throwsA(argumentErrorWithMessage('id must not be blank')),
      );
      expect(
        () => MapMarker(id: '   ', coordinate: validCoordinate),
        throwsA(argumentErrorWithMessage('id must not be blank')),
      );
    });

    test('shouldNotNormalizeId', () {
      final marker = MapMarker(
        id: '  memory-1  ',
        coordinate: validCoordinate,
      );

      expect(marker.id, '  memory-1  ');
    });

    test('shouldUseValueEqualityAndHashCode', () {
      final first = MapMarker(id: 'memory-1', coordinate: validCoordinate);
      final second = MapMarker(id: 'memory-1', coordinate: validCoordinate);
      final different = MapMarker(id: 'memory-2', coordinate: validCoordinate);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('shouldHaveSafeToString', () {
      final marker = MapMarker(
        id: 'memory-secret-id',
        coordinate: validCoordinate,
      );

      final text = marker.toString();

      expect(text, contains('hasId: true'));
      expect(text, isNot(contains('memory-secret-id')));
      expect(text, isNot(contains('41.7151')));
      expect(text, isNot(contains('44.8271')));
    });
  });
}

final MapCoordinate validCoordinate = MapCoordinate(
  latitude: 41.7151,
  longitude: 44.8271,
);

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
