import 'package:memory_map/features/profile/domain/account_display_name_failure.dart';

final class ProfileDisplayNameState {
  const ProfileDisplayNameState({
    this.isSaving = false,
    this.failure,
  });

  final bool isSaving;
  final AccountDisplayNameFailure? failure;

  bool get isBusy => isSaving;

  ProfileDisplayNameState copyWith({
    bool? isSaving,
    Object? failure = _sentinel,
  }) {
    return ProfileDisplayNameState(
      isSaving: isSaving ?? this.isSaving,
      failure: identical(failure, _sentinel)
          ? this.failure
          : failure as AccountDisplayNameFailure?,
    );
  }
}

const Object _sentinel = Object();
