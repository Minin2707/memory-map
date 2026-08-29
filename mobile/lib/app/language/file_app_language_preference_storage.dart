import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/app/language/app_language_preference_storage.dart';
import 'package:path_provider/path_provider.dart';

final appLanguagePreferenceStorageProvider =
    Provider<AppLanguagePreferenceStorage>((ref) {
  return const FileAppLanguagePreferenceStorage();
});

final class FileAppLanguagePreferenceStorage
    implements AppLanguagePreferenceStorage {
  const FileAppLanguagePreferenceStorage();

  static const String _fileName = 'app_language_preference.v1';

  @override
  Future<AppLanguagePreference?> read() async {
    try {
      final file = await _preferenceFile();
      if (!await file.exists()) {
        return null;
      }

      final value = await file.readAsString();
      return AppLanguagePreference.fromSerializedValue(value);
    } on Exception {
      throw const AppLanguagePreferenceStorageException();
    }
  }

  @override
  Future<void> write(AppLanguagePreference preference) async {
    try {
      final file = await _preferenceFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(preference.serializedValue, flush: true);
    } on Exception {
      throw const AppLanguagePreferenceStorageException();
    }
  }

  Future<File> _preferenceFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}$_fileName',
    );
  }
}
