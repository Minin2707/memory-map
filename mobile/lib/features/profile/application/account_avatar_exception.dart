import 'package:memory_map/features/profile/domain/account_avatar_failure.dart';

final class AccountAvatarApplicationException implements Exception {
  const AccountAvatarApplicationException(this.failure);

  final AccountAvatarFailure failure;
}
