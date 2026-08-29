import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/app/language/app_language_preference_state.dart';
import 'package:memory_map/app/language/app_language_preference_storage.dart';
import 'package:memory_map/app/language/file_app_language_preference_storage.dart';

final appLanguagePreferenceProvider = AsyncNotifierProvider<
    AppLanguagePreferenceNotifier, AppLanguagePreferenceState>(
  AppLanguagePreferenceNotifier.new,
);

final class AppLanguagePreferenceNotifier
    extends AsyncNotifier<AppLanguagePreferenceState> {
  @override
  Future<AppLanguagePreferenceState> build() async {
    try {
      final preference =
          await ref.watch(appLanguagePreferenceStorageProvider).read();
      return AppLanguagePreferenceState(
        preference: preference ?? AppLanguagePreference.system,
      );
    } on AppLanguagePreferenceStorageException {
      return const AppLanguagePreferenceState(
        hasPersistenceFailure: true,
      );
    }
  }

  Future<bool> selectPreference(AppLanguagePreference preference) async {
    final currentState =
        state.asData?.value ?? const AppLanguagePreferenceState();
    if (currentState.isSaving) {
      return false;
    }

    if (preference == currentState.preference &&
        !currentState.hasPersistenceFailure) {
      return true;
    }

    state = AsyncData(
      currentState.copyWith(
        isSaving: true,
        hasPersistenceFailure: false,
      ),
    );

    try {
      await ref
          .read(appLanguagePreferenceStorageProvider)
          .write(preference);
    } on AppLanguagePreferenceStorageException {
      if (ref.mounted) {
        state = AsyncData(
          currentState.copyWith(
            isSaving: false,
            hasPersistenceFailure: true,
          ),
        );
      }
      return false;
    }

    if (ref.mounted) {
      state = AsyncData(
        AppLanguagePreferenceState(preference: preference),
      );
    }
    return true;
  }
}
