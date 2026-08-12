import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';

void main() {
  group('MapSourceConfiguration', () {
    test('shouldCreateValidConfiguration', () {
      final configuration = MapSourceConfiguration(
        styleUri: 'https://example.invalid/style.json',
      );

      expect(configuration.styleUri, 'https://example.invalid/style.json');
    });

    test('shouldRejectBlankStyleUri', () {
      expect(
        () => MapSourceConfiguration(styleUri: ''),
        throwsA(argumentErrorWithMessage('styleUri must not be blank')),
      );
      expect(
        () => MapSourceConfiguration(styleUri: '   '),
        throwsA(argumentErrorWithMessage('styleUri must not be blank')),
      );
    });

    test('shouldNotNormalizeStyleUri', () {
      final configuration = MapSourceConfiguration(
        styleUri: '  https://example.invalid/style.json  ',
      );

      expect(
        configuration.styleUri,
        '  https://example.invalid/style.json  ',
      );
    });

    test('shouldUseValueEqualityAndHashCode', () {
      final first = MapSourceConfiguration(
        styleUri: 'https://example.invalid/style.json',
      );
      final second = MapSourceConfiguration(
        styleUri: 'https://example.invalid/style.json',
      );
      final different = MapSourceConfiguration(
        styleUri: 'https://example.invalid/other.json',
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('shouldHaveSafeToString', () {
      final configuration = MapSourceConfiguration(
        styleUri: 'https://example.invalid/SECRET_TOKEN/style.json',
      );

      final text = configuration.toString();

      expect(text, 'MapSourceConfiguration(configured: true)');
      expect(text, isNot(contains('https://example.invalid')));
      expect(text, isNot(contains('SECRET_TOKEN')));
      expect(text, isNot(contains('style.json')));
    });

    test('shouldExposeOpenFreeMapLibertyMvpSource', () {
      expect(
        MapSources.openFreeMapLiberty.styleUri,
        'https://tiles.openfreemap.org/styles/liberty',
      );
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
