import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/presentation/location_picker_map_configuration.dart';

void main() {
  group('LocationPickerMapConfiguration', () {
    test('shouldExposeOpenFreeMapLibertyStyleAsDefaultF8Configuration', () {
      expect(
        openFreeMapLocationPickerMapConfiguration.styleString,
        'https://tiles.openfreemap.org/styles/liberty',
      );
      expect(openFreeMapLocationPickerMapConfiguration.defaultLatitude, 0);
      expect(openFreeMapLocationPickerMapConfiguration.defaultLongitude, 0);
      expect(openFreeMapLocationPickerMapConfiguration.defaultZoom, 1.5);
      expect(openFreeMapLocationPickerMapConfiguration.selectedZoom, 12);
    });

    test('shouldCreateAlternateConfigurationForFutureProviderReplacement', () {
      final configuration = LocationPickerMapConfiguration(
        styleString: 'https://example.invalid/style.json',
        defaultLatitude: 10,
        defaultLongitude: 20,
        defaultZoom: 2,
        selectedZoom: 13,
      );

      expect(configuration.styleString, 'https://example.invalid/style.json');
      expect(configuration.defaultCameraLocation.latitude, 10);
      expect(configuration.defaultCameraLocation.longitude, 20);
      expect(configuration.defaultZoom, 2);
      expect(configuration.selectedZoom, 13);
    });

    test('shouldRejectInvalidConfiguration', () {
      expect(
        () => LocationPickerMapConfiguration(styleString: '   '),
        throwsA(argumentErrorWithMessage('styleString must not be blank')),
      );
      expect(
        () => LocationPickerMapConfiguration(
          styleString: 'style',
          defaultLatitude: 91,
        ),
        throwsA(
          argumentErrorWithMessage('defaultLatitude must be between -90 and 90'),
        ),
      );
      expect(
        () => LocationPickerMapConfiguration(
          styleString: 'style',
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
          styleString: 'style',
          defaultZoom: -1,
        ),
        throwsA(argumentErrorWithMessage('defaultZoom must not be negative')),
      );
      expect(
        () => LocationPickerMapConfiguration(
          styleString: 'style',
          selectedZoom: double.nan,
        ),
        throwsA(argumentErrorWithMessage('selectedZoom must not be negative')),
      );
    });

    test('shouldUseValueEqualityAndHashCode', () {
      final first = LocationPickerMapConfiguration(
        styleString: 'https://example.invalid/style.json',
      );
      final second = LocationPickerMapConfiguration(
        styleString: 'https://example.invalid/style.json',
      );
      final different = LocationPickerMapConfiguration(
        styleString: 'https://example.invalid/other.json',
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('shouldHaveSafeToString', () {
      final configuration = LocationPickerMapConfiguration(
        styleString: 'https://example.invalid/SECRET_TOKEN/style.json',
      );

      final text = configuration.toString();

      expect(text, contains('hasStyleString: true'));
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
