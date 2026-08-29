import 'package:memory_map/features/profile/domain/account_deletion_failure.dart';

final class AccountDeletionApplicationException implements Exception {
  const AccountDeletionApplicationException(this.failure);

  final AccountDeletionFailure failure;

  @override
  String toString() => 'AccountDeletionApplicationException($failure)';
}
