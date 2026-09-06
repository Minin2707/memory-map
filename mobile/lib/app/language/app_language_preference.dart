import 'package:flutter/widgets.dart';

enum AppLanguagePreference {
  system('system'),
  russian('ru'),
  english('en'),
  georgian('ka');

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
      AppLanguagePreference.georgian => const Locale('ka'),
    };
  }
}

Locale resolveMemoryStoryLocale(
  Locale? locale,
  Iterable<Locale> supportedLocales,
) {
  final languageCode = locale?.languageCode;
  if (languageCode != null) {
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == languageCode) {
        return supportedLocale;
      }
    }
  }

  return const Locale('en');
}
