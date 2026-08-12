import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/memory/presentation/location_picker_map_configuration.dart';

void main() {
  group('LocationPickerMapConfiguration', () {
    test('shouldUseOpenFreeMapLibertySourceAsDefaultF8Configuration', () {
      expect(
        openFreeMapLocationPickerMapConfiguration.sourceConfiguration,
        MapSources.openFreeMapLiberty,
      );
      expect(openFreeMapLocationPickerMapConfiguration.defaultLatitude, 0);
      expect(openFreeMapLocationPickerMapConfiguration.defaultLongitude, 0);
      expect(openFreeMapLocationPickerMapConfiguration.defaultZoom, 1.5);
      expect(openFreeMapLocationPickerMapConfiguration.selectedZoom, 12);
    });

    test('shouldCreateAlternateConfigurationForFutureProviderReplacement', () {
      final sourceConfiguration = MapSourceConfiguration(
        styleUri: 'https://example.invalid/style.json',
      );
      final configuration = LocationPickerMapConfiguration(
        sourceConfiguration: sourceConfiguration,
        defaultLatitude: 10,
        defaultLongitude: 20,
        defaultZoom: 2,
        selectedZoom: 13,
      );

      expect(configuration.sourceConfiguration, same(sourceConfiguration));
      expect(configuration.defaultCameraLocation.latitude, 10);
      expect(configuration.defaultCameraLocation.longitude, 20);
      expect(configuration.defaultZoom, 2);
      expect(configuration.selectedZoom, 13);
    });

    test('shouldRejectInvalidConfiguration', () {
      expect(
        () => LocationPickerMapConfiguration(
          defaultLatitude: 91,
        ),
        throwsA(
          argumentErrorWithMessage('defaultLatitude must be between -90 and 90'),
        ),
      );
      expect(
        () => LocationPickerMapConfiguration(
          defaultLongitude: -181,
        ),
        throwsA(
          argumentErrorWithMessage(
            'defaultLongitude must be between -180 and 180',
          ),
        ),
      );
      expect(
        () => LocationPickerMapConfiguration(
          defaultZoom: -1,
        ),
        throwsA(argumentErrorWithMessage('defaultZoom must not be negative')),
      );
      expect(
        () => LocationPickerMapConfiguration(
          selectedZoom: double.nan,
        ),
        throwsA(argumentErrorWithMessage('selectedZoom must not be negative')),
      );
    });

    test('shouldUseValueEqualityAndHashCode', () {
      final sourceConfiguration = MapSourceConfiguration(
        styleUri: 'https://example.invalid/style.json',
      );
      final first = LocationPickerMapConfiguration(
        sourceConfiguration: sourceConfiguration,
      );
      final second = LocationPickerMapConfiguration(
        sourceConfiguration: sourceConfiguration,
      );
      final different = LocationPickerMapConfiguration(
        sourceConfiguration: MapSourceConfiguration(
          styleUri: 'https://example.invalid/other.json',
        ),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('shouldHaveSafeToString', () {
      final configuration = LocationPickerMapConfiguration(
        sourceConfiguration: MapSourceConfiguration(
          styleUri: 'https://example.invalid/SECRET_TOKEN/style.json',
        ),
      );

      final text = configuration.toString();

      expect(text, contains('hasSourceConfiguration: true'));
      expect(text, contains('defaultZoom: 1.5'));
      expect(text, contains('selectedZoom: 12.0'));
      expect(text, isNot(contains('https://example.invalid')));
      expect(text, isNot(contains('SECRET_TOKEN')));
      expect(text, isNot(contains('style.json')));
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
