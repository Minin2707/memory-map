import 'package:memory_map/features/profile/application/account_deletion_exception.dart';
import 'package:memory_map/features/profile/application/account_avatar_exception.dart';
import 'package:memory_map/features/profile/application/account_display_name_exception.dart';
import 'package:memory_map/features/profile/data/remote/account_remote_data_source.dart';
import 'package:memory_map/features/profile/data/remote/account_remote_exception.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/profile/domain/account_avatar_failure.dart';
import 'package:memory_map/features/profile/domain/account_deletion_failure.dart';
import 'package:memory_map/features/profile/domain/account_display_name_failure.dart';
import 'package:memory_map/features/profile/domain/account_repository.dart';

final class DefaultAccountRepository implements AccountRepository {
  const DefaultAccountRepository(this._remoteDataSource);

  final AccountRemoteDataSource _remoteDataSource;

  @override
  Future<void> deleteCurrentAccount() async {
    try {
      await _remoteDataSource.deleteCurrentAccount();
    } on AccountRemoteOwnershipConflictException {
      throw const AccountDeletionApplicationException(
        AccountDeletionOwnershipConflict(),
      );
    } on AccountRemoteUnauthorizedException {
      throw const AccountDeletionApplicationException(
        AccountDeletionUnauthorized(),
      );
    } on AccountRemoteNetworkException {
      throw const AccountDeletionApplicationException(
        AccountDeletionNetworkUnavailable(),
      );
    } on AccountRemoteTimeoutException {
      throw const AccountDeletionApplicationException(
        AccountDeletionRequestTimedOut(),
      );
    } on AccountRemoteServerException {
      throw const AccountDeletionApplicationException(
        AccountDeletionServerFailure(),
      );
    } on AccountRemoteException {
      throw const AccountDeletionApplicationException(
        AccountDeletionUnknownFailure(),
      );
    }
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) async {
    try {
      return await _remoteDataSource.updateDisplayName(displayName);
    } on AccountRemoteException catch (exception) {
      throw AccountDisplayNameApplicationException(
        _mapDisplayNameFailure(exception),
      );
    }
  }

  @override
  Future<AuthUser> uploadCurrentUserAvatar(PreparedPhotoUpload photo) async {
    try {
      return await _remoteDataSource.uploadCurrentUserAvatar(photo);
    } on AccountRemoteException catch (exception) {
      throw AccountAvatarApplicationException(_mapAvatarFailure(exception));
    }
  }

  @override
  Future<AuthUser> removeCurrentUserAvatar() async {
    try {
      return await _remoteDataSource.removeCurrentUserAvatar();
    } on AccountRemoteException catch (exception) {
      throw AccountAvatarApplicationException(_mapAvatarFailure(exception));
    }
  }

  AccountAvatarFailure _mapAvatarFailure(AccountRemoteException exception) {
    return switch (exception) {
      AccountRemoteValidationException() =>
        const AccountAvatarValidationFailure(),
      AccountRemoteUnauthorizedException() => const AccountAvatarUnauthorized(),
      AccountRemoteNetworkException() =>
        const AccountAvatarNetworkUnavailable(),
      AccountRemoteTimeoutException() => const AccountAvatarRequestTimedOut(),
      AccountRemoteServerException() => const AccountAvatarServerFailure(),
      AccountRemoteOwnershipConflictException() ||
      AccountRemoteUnknownException() =>
        const AccountAvatarUnknownFailure(),
    };
  }

  AccountDisplayNameFailure _mapDisplayNameFailure(
    AccountRemoteException exception,
  ) {
    return switch (exception) {
      AccountRemoteValidationException() =>
        const AccountDisplayNameValidationFailure(),
      AccountRemoteUnauthorizedException() =>
        const AccountDisplayNameUnauthorized(),
      AccountRemoteNetworkException() =>
        const AccountDisplayNameNetworkUnavailable(),
      AccountRemoteTimeoutException() =>
        const AccountDisplayNameRequestTimedOut(),
      AccountRemoteServerException() =>
        const AccountDisplayNameServerFailure(),
      AccountRemoteOwnershipConflictException() ||
      AccountRemoteUnknownException() =>
        const AccountDisplayNameUnknownFailure(),
    };
  }
}
