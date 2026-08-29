import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/app/language/app_language_preference.dart';

void main() {
  group('AppLanguagePreference', () {
    test('shouldDeserializeKnownPreferenceValues', () {
      expect(
        AppLanguagePreference.fromSerializedValue('system'),
        AppLanguagePreference.system,
      );
      expect(
        AppLanguagePreference.fromSerializedValue('ru'),
        AppLanguagePreference.russian,
      );
      expect(
        AppLanguagePreference.fromSerializedValue('en'),
        AppLanguagePreference.english,
      );
    });

    test('shouldRejectUnknownPreferenceValues', () {
      expect(AppLanguagePreference.fromSerializedValue('fr'), isNull);
      expect(AppLanguagePreference.fromSerializedValue(''), isNull);
    });

    test('shouldMapExplicitPreferencesToFlutterLocale', () {
      expect(AppLanguagePreference.system.toFlutterLocale(), isNull);
      expect(
        AppLanguagePreference.russian.toFlutterLocale(),
        const Locale('ru'),
      );
      expect(
        AppLanguagePreference.english.toFlutterLocale(),
        const Locale('en'),
      );
    });
  });

  group('resolveMemoryStoryLocale', () {
    test('shouldUseRussianSystemLocaleWhenSupported', () {
      expect(
        resolveMemoryStoryLocale(
          const Locale('ru'),
          const [Locale('en'), Locale('ru')],
        ),
        const Locale('ru'),
      );
    });

    test('shouldFallbackUnsupportedSystemLocaleToEnglish', () {
      expect(
        resolveMemoryStoryLocale(
          const Locale('fr'),
          const [Locale('en'), Locale('ru')],
        ),
        const Locale('en'),
      );
    });

    test('shouldUseEnglishWhenSystemLocaleIsUnavailable', () {
      expect(
        resolveMemoryStoryLocale(null, const [Locale('en'), Locale('ru')]),
        const Locale('en'),
      );
    });
  });
}
