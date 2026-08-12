import 'package:memory_map/features/media/domain/media_failure.dart';

enum UploadPhotoPhase {
  idle,
  selecting,
  preparing,
  uploading,
}

final class UploadPhotoState {
  const UploadPhotoState({
    this.phase = UploadPhotoPhase.idle,
    this.failure,
  });

  final UploadPhotoPhase phase;
  final MediaFailure? failure;

  bool get isBusy => phase != UploadPhotoPhase.idle;

  bool get hasFailure => failure != null;

  UploadPhotoState copyWith({
    UploadPhotoPhase? phase,
    MediaFailure? failure,
    bool clearFailure = false,
  }) {
    return UploadPhotoState(
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UploadPhotoState &&
            phase == other.phase &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(phase, failure);

  @override
  String toString() {
    return 'UploadPhotoState(phase: $phase, hasFailure: $hasFailure)';
  }
}
