import 'package:memory_map/features/profile/domain/account_display_name_failure.dart';

final class AccountDisplayNameApplicationException implements Exception {
  const AccountDisplayNameApplicationException(this.failure);

  final AccountDisplayNameFailure failure;
}
