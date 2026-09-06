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
      expect(
        AppLanguagePreference.fromSerializedValue('ka'),
        AppLanguagePreference.georgian,
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
      expect(
        AppLanguagePreference.georgian.toFlutterLocale(),
        const Locale('ka'),
      );
    });
  });

  group('resolveMemoryStoryLocale', () {
    test('shouldUseRussianSystemLocaleWhenSupported', () {
      expect(
        resolveMemoryStoryLocale(
          const Locale('ru'),
          const [Locale('en'), Locale('ka'), Locale('ru')],
        ),
        const Locale('ru'),
      );
    });

    test('shouldUseGeorgianSystemLocaleWhenSupported', () {
      expect(
        resolveMemoryStoryLocale(
          const Locale('ka'),
          const [Locale('en'), Locale('ka'), Locale('ru')],
        ),
        const Locale('ka'),
      );
    });

    test('shouldUseEnglishSystemLocaleWhenSupported', () {
      expect(
        resolveMemoryStoryLocale(
          const Locale('en'),
          const [Locale('en'), Locale('ka'), Locale('ru')],
        ),
        const Locale('en'),
      );
    });

    test('shouldFallbackUnsupportedSystemLocaleToEnglish', () {
      expect(
        resolveMemoryStoryLocale(
          const Locale('fr'),
          const [Locale('en'), Locale('ka'), Locale('ru')],
        ),
        const Locale('en'),
      );
    });

    test('shouldUseEnglishWhenSystemLocaleIsUnavailable', () {
      expect(
        resolveMemoryStoryLocale(
          null,
          const [Locale('en'), Locale('ka'), Locale('ru')],
        ),
        const Locale('en'),
      );
    });
  });
}
