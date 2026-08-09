import 'package:memory_map/features/memory/domain/memory_failure.dart';

final class EditMemoryState {
  const EditMemoryState({
    this.isSaving = false,
    this.saveFailure,
  });

  final bool isSaving;
  final MemoryFailure? saveFailure;

  bool get hasSaveFailure => saveFailure != null;

  EditMemoryState copyWith({
    bool? isSaving,
    MemoryFailure? saveFailure,
    bool clearSaveFailure = false,
  }) {
    return EditMemoryState(
      isSaving: isSaving ?? this.isSaving,
      saveFailure: clearSaveFailure ? null : saveFailure ?? this.saveFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EditMemoryState &&
            isSaving == other.isSaving &&
            saveFailure == other.saveFailure;
  }

  @override
  int get hashCode => Object.hash(isSaving, saveFailure);

  @override
  String toString() {
    return 'EditMemoryState(isSaving: $isSaving, '
        'hasSaveFailure: $hasSaveFailure)';
  }
}
