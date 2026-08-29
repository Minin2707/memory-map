import 'package:memory_map/app/language/app_language_preference.dart';

abstract interface class AppLanguagePreferenceStorage {
  Future<AppLanguagePreference?> read();

  Future<void> write(AppLanguagePreference preference);
}

final class AppLanguagePreferenceStorageException implements Exception {
  const AppLanguagePreferenceStorageException();

  @override
  String toString() => 'AppLanguagePreferenceStorageException';
}
