import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:memory_map/features/memory/presentation/widgets/location_picker_map.dart';

void main() {
  group('LocationPickerMap readiness', () {
    test('shouldStartLoadingUntilStyleLoaded', () {
      final readiness = LocationPickerMapReadiness();

      expect(readiness.styleLoaded, isFalse);
      expect(readiness.isLoading, isTrue);
    });

    test('shouldTransitionOutOfLoadingWhenStyleLoads', () {
      final readiness = LocationPickerMapReadiness();

      final changed = readiness.markStyleLoaded();

      expect(changed, isTrue);
      expect(readiness.styleLoaded, isTrue);
      expect(readiness.isLoading, isFalse);
    });

    test('shouldIgnoreDuplicateStyleLoadedCallbacks', () {
      final readiness = LocationPickerMapReadiness();

      expect(readiness.markStyleLoaded(), isTrue);
      expect(readiness.markStyleLoaded(), isFalse);
      expect(readiness.isLoading, isFalse);
    });
  });

  group('LocationPickerMap conversion', () {
    test('shouldConvertMapLibreLatLngToMemoryLocationWithoutSwapping', () {
      final location = memoryLocationFromMapLibreLatLng(
        LatLng(41.7151, 44.8271),
      );

      expect(location.latitude, 41.7151);
      expect(location.longitude, 44.8271);
    });

    test('shouldPreserveAsymmetricSouthernWesternCoordinates', () {
      final location = memoryLocationFromMapLibreLatLng(
        LatLng(-12.0464, -77.0428),
      );

      expect(location.latitude, -12.0464);
      expect(location.longitude, -77.0428);
    });
  });
}
