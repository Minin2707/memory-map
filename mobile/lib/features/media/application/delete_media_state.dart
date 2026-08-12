import 'package:memory_map/features/media/domain/media_failure.dart';

final class DeleteMediaState {
  const DeleteMediaState({
    this.isDeleting = false,
    this.deleteFailure,
  });

  final bool isDeleting;
  final MediaFailure? deleteFailure;

  bool get hasDeleteFailure => deleteFailure != null;

  DeleteMediaState copyWith({
    bool? isDeleting,
    MediaFailure? deleteFailure,
    bool clearDeleteFailure = false,
  }) {
    return DeleteMediaState(
      isDeleting: isDeleting ?? this.isDeleting,
      deleteFailure:
          clearDeleteFailure ? null : deleteFailure ?? this.deleteFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeleteMediaState &&
            isDeleting == other.isDeleting &&
            deleteFailure == other.deleteFailure;
  }

  @override
  int get hashCode => Object.hash(isDeleting, deleteFailure);

  @override
  String toString() {
    return 'DeleteMediaState(isDeleting: $isDeleting, '
        'hasDeleteFailure: $hasDeleteFailure)';
  }
}
