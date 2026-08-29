import 'package:memory_map/features/profile/domain/account_avatar_failure.dart';

final class ProfileAvatarState {
  const ProfileAvatarState({
    this.isUploading = false,
    this.isRemoving = false,
    this.failure,
  });

  final bool isUploading;
  final bool isRemoving;
  final AccountAvatarFailure? failure;

  bool get isBusy => isUploading || isRemoving;

  ProfileAvatarState copyWith({
    bool? isUploading,
    bool? isRemoving,
    Object? failure = _sentinel,
  }) {
    return ProfileAvatarState(
      isUploading: isUploading ?? this.isUploading,
      isRemoving: isRemoving ?? this.isRemoving,
      failure: identical(failure, _sentinel)
          ? this.failure
          : failure as AccountAvatarFailure?,
    );
  }
}

const Object _sentinel = Object();
