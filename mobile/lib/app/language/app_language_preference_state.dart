import 'package:memory_map/app/language/app_language_preference.dart';

final class AppLanguagePreferenceState {
  const AppLanguagePreferenceState({
    this.preference = AppLanguagePreference.system,
    this.isSaving = false,
    this.hasPersistenceFailure = false,
  });

  final AppLanguagePreference preference;
  final bool isSaving;
  final bool hasPersistenceFailure;

  AppLanguagePreferenceState copyWith({
    AppLanguagePreference? preference,
    bool? isSaving,
    bool? hasPersistenceFailure,
  }) {
    return AppLanguagePreferenceState(
      preference: preference ?? this.preference,
      isSaving: isSaving ?? this.isSaving,
      hasPersistenceFailure:
          hasPersistenceFailure ?? this.hasPersistenceFailure,
    );
  }
}
