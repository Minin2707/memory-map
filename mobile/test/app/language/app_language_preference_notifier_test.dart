import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/app/language/app_language_preference_notifier.dart';
import 'package:memory_map/app/language/app_language_preference_storage.dart';
import 'package:memory_map/app/language/file_app_language_preference_storage.dart';

void main() {
  group('AppLanguagePreferenceNotifier', () {
    test('shouldDefaultToSystemWhenNoPreferenceIsPersisted', () async {
      final container = createContainer(FakeAppLanguagePreferenceStorage());
      addTearDown(container.dispose);

      final state = await container.read(appLanguagePreferenceProvider.future);

      expect(state.preference, AppLanguagePreference.system);
      expect(state.hasPersistenceFailure, isFalse);
    });

    test('shouldRestorePersistedPreference', () async {
      final container = createContainer(
        FakeAppLanguagePreferenceStorage(
          initialPreference: AppLanguagePreference.russian,
        ),
      );
      addTearDown(container.dispose);

      final state = await container.read(appLanguagePreferenceProvider.future);

      expect(state.preference, AppLanguagePreference.russian);
    });

    test('shouldRestorePersistedSystemPreference', () async {
      final container = createContainer(
        FakeAppLanguagePreferenceStorage(
          initialPreference: AppLanguagePreference.system,
        ),
      );
      addTearDown(container.dispose);

      final state = await container.read(appLanguagePreferenceProvider.future);

      expect(state.preference, AppLanguagePreference.system);
    });

    test('shouldRestorePersistedEnglishPreference', () async {
      final container = createContainer(
        FakeAppLanguagePreferenceStorage(
          initialPreference: AppLanguagePreference.english,
        ),
      );
      addTearDown(container.dispose);

      final state = await container.read(appLanguagePreferenceProvider.future);

      expect(state.preference, AppLanguagePreference.english);
    });

    test('shouldPersistSelectedPreference', () async {
      final storage = FakeAppLanguagePreferenceStorage();
      final container = createContainer(storage);
      addTearDown(container.dispose);
      await container.read(appLanguagePreferenceProvider.future);

      final didSave = await container
          .read(appLanguagePreferenceProvider.notifier)
          .selectPreference(AppLanguagePreference.english);

      final state = container.read(appLanguagePreferenceProvider).requireValue;
      expect(didSave, isTrue);
      expect(storage.storedPreference, AppLanguagePreference.english);
      expect(storage.writes, <AppLanguagePreference>[
        AppLanguagePreference.english,
      ]);
      expect(state.preference, AppLanguagePreference.english);
      expect(state.hasPersistenceFailure, isFalse);
    });

    test('shouldKeepCurrentPreferenceWhenPersistenceFails', () async {
      final storage = FakeAppLanguagePreferenceStorage(
        initialPreference: AppLanguagePreference.russian,
      )..writeFailure = const AppLanguagePreferenceStorageException();
      final container = createContainer(storage);
      addTearDown(container.dispose);
      await container.read(appLanguagePreferenceProvider.future);

      final didSave = await container
          .read(appLanguagePreferenceProvider.notifier)
          .selectPreference(AppLanguagePreference.english);

      final state = container.read(appLanguagePreferenceProvider).requireValue;
      expect(didSave, isFalse);
      expect(state.preference, AppLanguagePreference.russian);
      expect(state.hasPersistenceFailure, isTrue);
    });
  });
}

ProviderContainer createContainer(
  AppLanguagePreferenceStorage storage,
) {
  return ProviderContainer(
    overrides: [
      appLanguagePreferenceStorageProvider.overrideWithValue(storage),
    ],
  );
}

final class FakeAppLanguagePreferenceStorage
    implements AppLanguagePreferenceStorage {
  FakeAppLanguagePreferenceStorage({
    AppLanguagePreference? initialPreference,
  }) : storedPreference = initialPreference;

  AppLanguagePreference? storedPreference;
  Object? writeFailure;
  final List<AppLanguagePreference> writes = <AppLanguagePreference>[];

  @override
  Future<AppLanguagePreference?> read() async {
    return storedPreference;
  }

  @override
  Future<void> write(AppLanguagePreference preference) async {
    final failure = writeFailure;
    if (failure != null) {
      throw failure;
    }

    writes.add(preference);
    storedPreference = preference;
  }
}
