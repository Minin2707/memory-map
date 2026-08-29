import 'package:flutter/widgets.dart';

enum AppLanguagePreference {
  system('system'),
  russian('ru'),
  english('en');

  const AppLanguagePreference(this.serializedValue);

  final String serializedValue;

  static AppLanguagePreference? fromSerializedValue(String value) {
    final normalized = value.trim().toLowerCase();
    for (final preference in values) {
      if (preference.serializedValue == normalized) {
        return preference;
      }
    }

    return null;
  }

  Locale? toFlutterLocale() {
    return switch (this) {
      AppLanguagePreference.system => null,
      AppLanguagePreference.russian => const Locale('ru'),
      AppLanguagePreference.english => const Locale('en'),
    };
  }
}

Locale resolveMemoryStoryLocale(
  Locale? locale,
  Iterable<Locale> supportedLocales,
) {
  final supportsRussian = supportedLocales.any(
    (supportedLocale) => supportedLocale.languageCode == 'ru',
  );
  if (supportsRussian && locale?.languageCode == 'ru') {
    return const Locale('ru');
  }

  return const Locale('en');
}
