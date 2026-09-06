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
      final generation = readiness.beginControllerLifecycle();

      final changed = readiness.markStyleLoaded(generation);

      expect(changed, isTrue);
      expect(readiness.styleLoaded, isTrue);
      expect(readiness.isLoading, isFalse);
    });

    test('shouldIgnoreDuplicateStyleLoadedCallbacks', () {
      final readiness = LocationPickerMapReadiness();
      final generation = readiness.beginControllerLifecycle();

      expect(readiness.markStyleLoaded(generation), isTrue);
      expect(readiness.markStyleLoaded(generation), isFalse);
      expect(readiness.isLoading, isFalse);
    });

    test('shouldResetReadinessForNewControllerLifecycle', () {
      final readiness = LocationPickerMapReadiness();

      final firstGeneration = readiness.beginControllerLifecycle();
      expect(readiness.markStyleLoaded(firstGeneration), isTrue);
      expect(readiness.isLoading, isFalse);

      final secondGeneration = readiness.beginControllerLifecycle();

      expect(secondGeneration, isNot(firstGeneration));
      expect(readiness.isLoading, isTrue);
      expect(readiness.isStyleLoadedFor(firstGeneration), isFalse);
      expect(readiness.isStyleLoadedFor(secondGeneration), isFalse);
    });

    test('shouldIgnoreStyleLoadedCallbackFromPreviousControllerLifecycle', () {
      final readiness = LocationPickerMapReadiness();

      final firstGeneration = readiness.beginControllerLifecycle();
      final secondGeneration = readiness.beginControllerLifecycle();

      expect(readiness.markStyleLoaded(firstGeneration), isFalse);
      expect(readiness.isLoading, isTrue);
      expect(readiness.markStyleLoaded(secondGeneration), isTrue);
      expect(readiness.isStyleLoadedFor(secondGeneration), isTrue);
    });

    test('shouldRejectStyleLoadedCallbackAfterDispose', () {
      final readiness = LocationPickerMapReadiness();
      final generation = readiness.beginControllerLifecycle();

      readiness.dispose();

      expect(readiness.markStyleLoaded(generation), isFalse);
      expect(readiness.isStyleLoadedFor(generation), isFalse);
      expect(readiness.isLoading, isTrue);
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
