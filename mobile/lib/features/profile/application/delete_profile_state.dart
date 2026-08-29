import 'package:memory_map/features/profile/domain/account_deletion_failure.dart';

final class DeleteProfileState {
  const DeleteProfileState({this.isDeleting = false, this.failure});

  final bool isDeleting;
  final AccountDeletionFailure? failure;

  DeleteProfileState copyWith({
    bool? isDeleting,
    Object? failure = _sentinel,
  }) {
    return DeleteProfileState(
      isDeleting: isDeleting ?? this.isDeleting,
      failure: identical(failure, _sentinel)
          ? this.failure
          : failure as AccountDeletionFailure?,
    );
  }
}

const Object _sentinel = Object();
